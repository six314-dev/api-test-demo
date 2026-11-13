# -*- coding: utf-8 -*-
"""
run_sql.py —— 本机 SQL Server 脚本执行器（W1 起一直用到 W10）

【为什么需要这个文件】
本机 SSMS 主程序缺失，pyodbc 又被系统「应用程序控制策略」拦截，
所以不能直接连库。但 sqlcmd（SQL Server 自带命令行工具）是可用的。
本脚本把 sqlcmd 的三个坑一次性封死：
  1. -i 后面的路径必须是「反斜杠绝对路径」，正斜杠会报「打开文件 D: 拒绝访问」
  2. 必须加 -f 65001，否则 UTF-8 文件里的中文会被按 GBK 读，导致 SQL 引号错位
  3. sqlcmd 的输出是 GBK 编码，Python 要用 gbk 解码才能看到中文
  4. 必须加 -b：sqlcmd 默认「某条语句报错也不改返回码」，会假装成功。
     实测过：外键冲突导致 0 条订单插入，返回码依旧是 0。加了 -b 才会真正失败。
  5. 刚开机 / 刚唤醒时服务虽 Running、但命名管道未就绪，会报「登录超时已过期」。
     这类连接错误自动重试 2 次（间隔 2 秒）；SQL 语法错不重试，避免白等。

【怎么用】（在 VS Code 终端里，先确保当前目录是项目根目录）
    python utils/run_sql.py sql/00_env_check.sql        # 执行一个 .sql 文件
    python utils/run_sql.py -q "SELECT COUNT(*) FROM orders"   # 直接跑一句查询
    python utils/run_sql.py -d DQ_Verify sql/xxx.sql    # 换一个数据库执行

【参数说明】
    -E   Windows 集成认证（不用输密码）
    -C   信任服务器自签名证书，不加会报 SSL/certificate 错误
    -W   去掉每列尾部的空格，输出更整齐
    -f 65001  输入文件按 UTF-8 读（VS Code 保存的默认编码）
    -i   要执行的脚本文件；sqlcmd 原生支持脚本里的 GO 批处理分隔
"""

import os
import re
import sys
import subprocess
import argparse
import time

# ---------------------------------------------------------------------------
# 1. 固定配置：这些路径是 2026-11-13 实测过的，不要随便改
# ---------------------------------------------------------------------------
# sqlcmd 在 D 盘（不在 C 盘），版本 15.0.2000.5，对应 ODBC Driver 17
SQLCMD = r"D:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE"
SERVER = "localhost"       # 默认实例 MSSQLSERVER，直接写 localhost 即可
DEFAULT_DB = "DQTest"      # W1 新建的练习库

# 项目根目录 = 本文件的上一级目录（utils/ 的爸爸）
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# 2. 连接类错误的特征词
#    实测：Windows 刚开机 / 刚唤醒时，SQL Server 服务虽是 Running，
#    命名管道却还没完全就绪，sqlcmd 会等约 10 秒后报「登录超时已过期」。
#    这类错误重试 2 次就能过，不必让用户手动重敲。
#    注意：SQL 语法错、约束冲突不能重试，重试只会白等。
# ---------------------------------------------------------------------------
CONN_ERROR_HINTS = (
    "命名管道提供程序", "登录超时已过期", "无法打开与 SQL Server 的连接",
    "找不到或无法访问服务器", "SQL Server 不存在或访问被拒绝",
    "Named Pipes Provider", "Login timeout expired", "Could not open a connection",
)


def is_connection_error(out: str, err: str) -> bool:
    """判断这次是「连不上服务器」还是「SQL 写错了」。"""
    text = out + err
    return any(hint in text for hint in CONN_ERROR_HINTS)


def decode_sqlcmd_output(raw: bytes, prefer: str = "gbk") -> str:
    """把 sqlcmd 的输出转成能看的中文。

    实测有个诡异差异：
      * -i 执行脚本文件时，输出是 GBK
      * -Q 直接跑一句查询时，输出是 UTF-8
    两种字节流互相误解码都会变成乱码，所以按调用方式指定优先编码。
    """
    order = [prefer] + [e for e in ("gbk", "utf-8") if e != prefer]
    for enc in order:
        try:
            text = raw.decode(enc)
            # 替换符太多说明解码错编码，换下一种
            if text.count("\ufffd") < 3:
                return text
        except UnicodeDecodeError:
            continue
    return raw.decode("gbk", errors="replace")


def build_args(script_path=None, query=None, db=DEFAULT_DB):
    """拼 sqlcmd 的参数列表。

    用 list 传参（而不是拼一整条字符串）是为了绕开 shell 转义，
    也避免路径里的空格被拆成两个参数。
    """
    args = [SQLCMD, "-S", SERVER, "-E", "-C", "-W", "-b", "-f", "65001", "-d", db]
    if script_path:
        # 关键：转成「反斜杠绝对路径」，正斜杠 sqlcmd 不认
        abs_path = os.path.abspath(script_path).replace("/", os.sep)
        args += ["-i", abs_path]
    elif query:
        args += ["-Q", query]
    else:
        raise ValueError("必须给一个 .sql 文件或用 -q 给一条 SQL")
    return args


def main():
    parser = argparse.ArgumentParser(description="执行本机 SQL Server 脚本")
    parser.add_argument("script", nargs="?", help="要执行的 .sql 文件路径（相对项目根目录）")
    parser.add_argument("-q", "--query", help="直接执行一条 SQL，不读文件")
    parser.add_argument("-d", "--database", default=DEFAULT_DB, help="目标数据库，默认 DQTest")
    ns = parser.parse_args()

    if not ns.script and not ns.query:
        parser.print_help()
        return 1
    if not os.path.isfile(SQLCMD):
        print("[错误] 找不到 sqlcmd：", SQLCMD)
        return 1

    script = None
    if ns.script:
        # 允许写相对路径；先按「相对于项目根目录」找，再按「相对于当前目录」找
        candidate = os.path.join(ROOT, ns.script)
        script = candidate if os.path.isfile(candidate) else ns.script
        if not os.path.isfile(script):
            print("[错误] 找不到脚本：", ns.script)
            print("  项目根目录：", ROOT)
            return 1

    args = build_args(script, ns.query, ns.database)
    print("=" * 64)
    print("执行：", ns.script or ns.query)
    print("数据库：", ns.database)
    print("=" * 64)

    started = time.time()
    prefer = "utf-8" if ns.query else "gbk"
    max_attempts = 3
    proc = None
    out = err = ""
    for attempt in range(1, max_attempts + 1):
        proc = subprocess.run(args, capture_output=True, cwd=ROOT)
        out = decode_sqlcmd_output(proc.stdout, prefer)
        err = decode_sqlcmd_output(proc.stderr, prefer)
        # 只有「连不上服务器」才重试；SQL 写错重试 3 次只会白等
        if attempt < max_attempts and is_connection_error(out, err):
            print("[连接] SQL Server 暂未就绪（服务刚启动时常见），2 秒后重试 %d/%d ..."
                  % (attempt + 1, max_attempts))
            time.sleep(2)
            continue
        break
    elapsed = time.time() - started

    if out.strip():
        print(out.strip())
    if err.strip():
        print("[sqlcmd 提示/错误]")
        print(err.strip())

    # 兜底：有些错误 sqlcmd 仍可能给返回码 0，这里再按「错误级别 >= 16」扫一遍
    # 中文版报「消息 547，级别 16」，英文版报「Msg 547, Level 16」
    severe_pattern = r"(消息\s*\d+[，,]\s*级别\s*(?:1[6-9]|2\d))|(Msg\s*\d+,\s*Level\s*(?:1[6-9]|2\d))"
    has_sql_error = bool(re.search(severe_pattern, out + err, flags=re.IGNORECASE))

    print("-" * 64)
    ok = (proc.returncode == 0) and not has_sql_error
    print("返回码：", proc.returncode, "| 耗时：%.2fs" % elapsed,
          "|", "成功" if ok else "失败（有报错，往上翻）")
    if has_sql_error:
        print("[!] 检测到 SQL 错误（级别 >= 16），本次执行不算成功，别往下走")
    if not ok and is_connection_error(out, err):
        print("[!] 这是连接问题，不是你 SQL 写错。等 30 秒再跑一次即可。")
        print("    仍不行就在 PowerShell 里敲：Get-Service MSSQLSERVER 看是否 Running")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
