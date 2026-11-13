# api-test-demo

数据质量测试 + 接口自动化学习项目。仓库名沿用最初的 `api-test-demo`（不改名，避免 SSH 远端地址失效）。

**当前方向**：用 SQL 验证数据从产生 → 流转 → 呈现的正确性，配合 Python / pytest 做接口与数据联动的自动化校验。总纲见 `学习计划/软件测试求职规划_v3_数据质量测试_28周.md`。

## 技术栈

| 用途 | 工具 |
|---|---|
| 语言 | Python 3.13 |
| 数据库 | 本机 SQL Server 2019（库 `DQTest`），通过 `sqlcmd` 执行脚本 |
| 测试框架 | pytest 9.x |
| HTTP 请求 | requests / Postman |
| 测试报告 | allure-pytest（W10） |
| 版本管理 | Git + GitHub（SSH over 443） |
| 编辑器 | VS Code |

## 目录结构

```
api-test-demo/
├── sql/                # W1 起：建表、造数、查询练习脚本
│   ├── 00_env_check.sql      # Day 0 环境验证（在 master 库执行）
│   ├── 01_create_tables.sql  # 周二：自己写，建 4 张业务表
│   ├── 02_seed_data.sql      # 周四：自己写，灌 500 条订单
│   ├── 03_查询练习.sql        # 周六：自己写，10 道查询题
│   └── _answer/              # 保底答案，卡满 30 分钟才准看
├── utils/
│   └── run_sql.py            # SQL 脚本执行器（封装 sqlcmd 的 4 个坑）
├── tests/              # pytest 用例
├── data/               # 测试数据（JSON / YAML / CSV）
├── docs/               # 用例文档、练习记录、复盘
├── reports/            # 测试报告输出（不提交到仓库）
├── requirements.txt
├── .gitignore
└── README.md
```

## 环境准备

本机固定使用下面这个 Python 解释器，避免多套 Python 装错地方：

```
C:\Users\长乐\AppData\Local\Programs\Python\Python313\python.exe
```

安装 Python 依赖：

```bash
python -m pip install -r requirements.txt
```

### Git 环境

本机**未独立安装 Git for Windows**，使用 WorkBuddy 内置便携版：

```
C:\Program Files\WorkBuddy\resources\vendor\PortableGit\cmd
```

该目录已追加到用户级 PATH（2026-11-13）。若终端报「无法将 git 项识别为 cmdlet」，**完全退出 VS Code 再打开**即可；不想重启就在当前终端临时执行：

```powershell
$env:Path += ";C:\Program Files\WorkBuddy\resources\vendor\PortableGit\cmd"
```

推送走 SSH over 443（`~/.ssh/config`），`core.sshCommand` 指向系统 OpenSSH；`git ls-remote origin HEAD` 可随时做只读连通性检查。

### SQL 环境（W1 起）

本机 SSMS 主程序缺失、`pyodbc` 被系统应用控制策略拦截，因此用 SQL Server 自带的 `sqlcmd`，由 `utils/run_sql.py` 统一封装。脚本只用 Python 标准库，任一 Python 3 都能跑。

```bash
# Day 0：建库并验证连接（必须是 -d master）
python utils/run_sql.py -d master sql/00_env_check.sql

# 之后执行自己的脚本
python utils/run_sql.py sql/01_create_tables.sql

# 临时跑一句查询（Day 0 用这条；FROM orders 要等 W1 周二建表后才能查）
python utils/run_sql.py -q "SELECT DB_NAME() AS db, GETDATE() AS now"
```

> 执行器已处理：反斜杠路径、`-f 65001` 中文编码、输出编码判断、`-b` 错误返回码与"级别 >= 16"错误扫描、连接未就绪自动重试（SQL 写错不重试）。**别绕过它直接敲 sqlcmd**。

## 如何运行

```bash
python -m pytest tests/ -v
```

## 进度

- [x] 搭建项目骨架、GitHub 仓库上线
- [x] 登录功能测试用例设计（5 条，见 `docs/test-cases-login.md`）
- [x] 首个 pytest 接口脚本（3 条用例，全部 PASSED）
- [x] SQL 练习环境就绪：`DQTest` 库 + 执行器 + 4 张表规格
- [ ] **W1（进行中）**：建 4 张表、灌 500 条订单、过完 SQL 清单 1—10
- [ ] W2：跨 3 表对账 SQL（清单 11—21）
- [ ] W3：埋 10 个数据问题再逐个揪出来
- [ ] W5—W10：接口 + 数据联动、pytest 改造、项目一收尾
- [ ] Allure 报告 / GitHub Actions 持续集成

## 说明

本项目为个人学习项目，用于练习数据校验与接口测试设计，不作为生产代码使用。
