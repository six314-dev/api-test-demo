# -*- coding: utf-8 -*-
"""
我的第一个接口自动化测试脚本
====================================
测试目标：jsonplaceholder.typicode.com（一个免费的练习用接口网站）
它假装是一个"用户管理系统"，我们拿它练手最安全——怎么测都不会弄坏东西。

这个文件里写了 3 条测试，对应你用例文档里的思路：
  1. 查询一个存在的用户     → 应该成功（对应 TC-LOGIN-001 正向用例的思路）
  2. 查询一个不存在的用户   → 应该返回 404（对应异常用例的思路）
  3. 检查返回的数据内容     → 不只看状态码，还要看字段值（深入断言）

运行方法：在 VS Code 内置终端里输入  pytest tests/test_first_api.py -v
"""

# 第 1 步：导入需要的工具
# requests 是"服务员"——负责把请求发出去、把结果带回来
import requests

# pytest 是"厨师长"——不需要显式导入它的函数，
# 但只要文件名以 test_ 开头、函数名也以 test_ 开头，pytest 就会自动发现并运行它们


# 第 2 步：定义要测试的接口地址（就像快递单上的收货地址）
BASE_URL = "https://jsonplaceholder.typicode.com"


# ============================================================
# 测试 1：正向用例 —— 查一个真实存在的用户（编号 1）
# ============================================================
def test_get_existing_user():
    """查询存在的用户，预期返回 200 和正确的数据"""

    # 发起 GET 请求：GET 就是"我要读取数据"
    # 相当于问服务器："请把 1 号用户的资料给我"
    response = requests.get(f"{BASE_URL}/users/1")

    # ---- 断言部分（验收动作）----

    # 断言 1：状态码应该是 200（成功）
    # response.status_code 就是服务器返回的状态码
    assert response.status_code == 200, (
        f"失败了！预期 200，实际返回 {response.status_code}"
    )

    # 断言 2：返回的 JSON 里，name 字段应该是这个值
    # response.json() 把服务器返回的 JSON 文本变成 Python 字典
    data = response.json()
    assert data["name"] == "Leanne Graham", (
        f"用户名不对！实际返回 {data['name']}"
    )

    # 断言 3：检查邮箱字段确实存在且包含 @ 符号
    # "in" 是 Python 的语法，意思是"包含在"
    assert "@" in data["email"], (
        f"邮箱格式不对！实际返回 {data['email']}"
    )

    # 走到这里没有任何报错 = 3 条断言全部通过 = 测试成功


# ============================================================
# 测试 2：异常用例 —— 查一个不存在的用户（编号 999）
# ============================================================
def test_get_nonexistent_user():
    """查询不存在的用户，预期返回 404（找不到）"""

    # 向服务器要 999 号用户——这个用户根本不存在
    response = requests.get(f"{BASE_URL}/users/999")

    # 断言：服务器应该明确告诉我们"404 Not Found"
    # 一个设计良好的接口，对不存在的资源必须返回 404，而不是瞎返回别的
    assert response.status_code == 404, (
        f"预期 404（找不到），实际返回 {response.status_code}，"
        f"接口的异常处理可能有问题！"
    )


# ============================================================
# 测试 3：批量查询 —— 一次拿所有用户，检查数量和结构
# ============================================================
def test_get_all_users():
    """查询全部用户列表，预期返回 200 且至少有 5 个用户"""

    # 注意地址没有 /1 这种编号，就是 /users，意思是"把用户列表全给我"
    response = requests.get(f"{BASE_URL}/users")

    # 断言 1：状态码成功
    assert response.status_code == 200

    # 断言 2：返回的应该是一个列表（list），里面每个元素是一个用户字典（dict）
    # isinstance(x, 类型) 是 Python 判断"x 是不是这个类型"的写法
    data = response.json()
    assert isinstance(data, list), "返回的应该是一个用户列表"

    # 断言 3：这个练习数据集有 10 个用户，我们检查数量 >= 5
    # len() 是 Python 计算"列表里有几个元素"的函数
    assert len(data) >= 5, f"用户数量异常！只返回了 {len(data)} 个"

    # 断言 4（深入检查）：每个用户都应该有 id、name、email 这三个字段
    # for 循环 = 把列表里每个用户挨个检查一遍
    for user in data:
        assert "id" in user, f"用户缺少 id 字段: {user}"
        assert "name" in user, f"用户缺少 name 字段: {user}"
        assert "email" in user, f"用户缺少 email 字段: {user}"
