# 开发进度

## S0（2026-11-04）

空项目、新建仓库；没有开始基线 HEAD 或已有用户改动。未发现适用 AGENTS.md。Git 身份由用户提供，仅配置本仓库。工具：MoonBit 20261012；Python 3.14；cc 可用；Node/R 不可用。

完成：GitHub API + Mooncakes 原生查重；三份跨人口统计/体检/实验室公开数据下载，V5 魔数和 SHA-256 已登记；pyreadstat 1.3.7 全文件参考读取成功。规范已阅读到描述符和缺失布局。V5 行数歧义采用严格诊断/显式提示，边界按对齐和完整结构验证。

命令：`python3 tools/research.py`（成功）；Mooncakes API 五组查询（成功）；`.cache/venv/bin/python` 调用 pyreadstat.read_xport(disable_datetime_conversion=True)（三份成功）。Python xport 初次调用遇 pandas 3 构造器不兼容，已准备独立构造器兼容适配，解析算法不变。native 构建探针待 S1。

下一步：S1 工程、模型、流接口和交换契约。S1–S6 尚未完成。网络由授权沙箱外命令完成，发布无需验证工具运行时。

## S1 完成

C02 native 基线 7189a47。模型/流 I/O/诊断及交换契约已实现。`moon check --target native --deny-warn`、`moon test --target native --deny-warn`（4/4）、`moon build --target native --deny-warn` 和 native 探针运行通过。当前工具链 Bytes 不可变，构造使用受限 Array 后转 Bytes；采用 Debug 派生和 errdefer；仅关闭旧式 Eq 方法自动提升弃用警告。下一步 S2。

## S2 完成

C04 0b5d524；C05 df3dd87；C06 2404cf6。核心 reader 为拉取式，按物理块验证候选成员，失败候选有界回放。严格策略拒绝短空白尾部及成员/数据双重解释；显式 trim 或逐成员行数提示可消除约定层歧义。完整行原始字节可访问。

真实扫描发现并修复 MEMBER 的 160 字段起点应为 65（合成夹具起初也用了错误偏移），已补独立真实输入验证。三份样本扫描得到 9254×46、8704×21、3036×4；完整数值对照由 tools/compare_scan.py 执行，数值容差 1 ULP（ReadStat 截断与本库最近舍入差异），精确整数与缺失不使用容差。`moon test --target native --deny-warn` 12/12；检查和构建通过。下一步 S3 writer。

## S3 完成

C08 796fe45：验证 schema、确定性头部与 140 字节输出。writer 逐行写有限数值/缺失/字符，支持空成员和多个不同 schema，错误后不可继续/finish，原始行写入保留低位。输出字节上限在写入前检查。

`moon test --target native --deny-warn` 15/15；examples/write 生成 NUMBERS(3)、WORDS(3)、TAGS(28)、EMPTY(0)。`tools/check_writer.py` 由独立 Python xport 3.6.1 读取全部成员和值；28 个标记用独立字节向量精确检查。pyreadstat 1.3.7 把该多成员文件后续头部误作数据，返回首成员 145 行，因此仅对单成员切片做 ReadStat 对照，绝不当作多成员证据。下一步 S4 CLI 与 CSV/JSON。

## S4 完成

C10 c46d08c；C11 fd72a23。inspect/export/write 三条 native 命令已贯通。C10 集成检查发现 Int64 默认 JSON 产生字符串，提交先于确认发生；C11 已显式输出精确十进制 JSON number，并重新通过 CLI 集成检查。

检查：`moon test --target native --deny-warn` 20/20；tools/test_inspect.py、tools/test_export.py、tools/test_exchange.py 均通过。三份真实样本完成 inspect→CSV/JSON→write→pyreadstat 全列全值和全部已声明元数据比较（tools/validate_corpus.py），620612 单元格，实际 0 ULP 差异。

平台采用同目录独占临时文件、同步和 no-replace 发布；普通错误对 CSV/JSON 成组回滚；--force 保留旧文件备份直至成组成功。进程退出清理临时文件，机器崩溃跨文件原子性不作保证；回滚遇并发外部改动时保留恢复备份并报错。核心/交换层不依赖文件系统或 oracle。下一步 S5 独立生成输入、异常、流式/RSS 和完整证据整理。
