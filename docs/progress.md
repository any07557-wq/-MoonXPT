# 开发进度

## S0（2026-11-04）

空项目、新建仓库；没有开始基线 HEAD 或已有用户改动。未发现适用 AGENTS.md。Git 身份由用户提供，仅配置本仓库。工具：MoonBit 20261012；Python 3.14；cc 可用；Node/R 不可用。

完成：GitHub API + Mooncakes 原生查重；三份跨人口统计/体检/实验室公开数据下载，V5 魔数和 SHA-256 已登记；pyreadstat 1.3.7 全文件参考读取成功。规范已阅读到描述符和缺失布局。V5 行数歧义采用严格诊断/显式提示，边界按对齐和完整结构验证。

命令：`python3 tools/research.py`（成功）；Mooncakes API 五组查询（成功）；`.cache/venv/bin/python` 调用 pyreadstat.read_xport(disable_datetime_conversion=True)（三份成功）。Python xport 初次调用遇 pandas 3 构造器不兼容，已准备独立构造器兼容适配，解析算法不变。native 构建探针待 S1。

下一步：S1 工程、模型、流接口和交换契约。S1–S6 尚未完成。网络由授权沙箱外命令完成，发布无需验证工具运行时。

## S1 完成

C02 native 基线 7189a47。模型/流 I/O/诊断及交换契约已实现。`moon check --target native --deny-warn`、`moon test --target native --deny-warn`（4/4）、`moon build --target native --deny-warn` 和 native 探针运行通过。当前工具链 Bytes 不可变，构造使用受限 Array 后转 Bytes；采用 Debug 派生和 errdefer；仅关闭旧式 Eq 方法自动提升弃用警告。下一步 S2。
