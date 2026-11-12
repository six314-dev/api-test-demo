# api-test-demo

接口自动化测试学习项目 —— 从零开始搭建的一套可运行、可展示的接口测试工程。

## 项目目标

用 Python + requests + pytest 对一个公开 REST API 编写接口自动化测试，覆盖：

- 冒烟用例：核心接口能正常返回
- 正向用例：参数正确时业务结果符合预期
- 反向用例：参数缺失、类型错误、ID 不存在等异常场景
- 数据驱动：用例数据与代码分离
- 测试报告：Allure 生成可视化报告（进阶）
- 持续集成：GitHub Actions 每次提交自动跑测试（进阶）

## 技术栈

| 用途 | 工具 |
|---|---|
| 语言 | Python 3.13 |
| 测试框架 | pytest 9.x |
| HTTP 请求 | requests |
| 测试报告 | allure-pytest（进阶：allure 命令行） |
| 版本管理 | Git + GitHub |
| 编辑器 | VS Code |
| 接口调试 | Postman |

## 目录结构

```
api-test-demo/
├── tests/              # 测试用例（按模块拆分）
├── data/               # 测试数据（JSON / YAML / CSV）
├── utils/              # 公共方法：请求封装、断言、日志
├── docs/               # 测试用例文档、设计说明
├── reports/            # 测试报告输出（不提交到仓库）
├── requirements.txt    # 依赖清单
├── .gitignore
└── README.md
```

## 环境准备

本机固定使用下面这个 Python 解释器，避免多套 Python 装错地方：

```
C:\Users\长乐\AppData\Local\Programs\Python\Python313\python.exe
```

安装依赖：

```bash
python -m pip install -r requirements.txt
```

## 如何运行（待补充）

用例编写完成后补充：

```bash
python -m pytest tests/ -v
```

## 进度

- [x] 搭建项目骨架
- [x] 登录功能测试用例设计（5 条，见 `docs/test-cases-login.md`）
- [ ] 完成第一个公开 API 的接口测试
- [ ] 用例分层：冒烟 / 正向 / 反向
- [ ] 数据驱动改造
- [ ] Allure 报告
- [ ] GitHub Actions 持续集成

## 说明

本项目为个人学习项目，用于练习接口测试设计与工程化能力，不作为生产代码使用。
