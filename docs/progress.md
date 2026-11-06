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

## S5 完成

C13 49990b2；独立输入、数值/缺失、三真实语料对照已完整。异常阶段修复 exact-limit EOF、CSV 极小非零数 underflow、nullable诊断字段、未命中行数提示；加强头部保留字段校验和 CLI 选项作用域，写入输出字节上限与输入上限独立。27个测试组、79个截断、256个变异、8个定向错误通过；输出冲突回滚真实执行。

release合成导出/写入1万、10万、100万行的 RSS 均约2.5–3.1MiB，原始统计已入 docs/benchmark-results.json；没有冒称生产负载。最终矩阵逐项有证据。下一步 S6 固定依赖、CI、干净检出复现、API/赛事交接与提交审计。官方历史工具链 URL 的 HEAD 请求403，安装脚本可读取；须公开安装验证边界，不把联网失败写成通过。

S5 数值边界补充决策：最近舍入会将最大合法正规化 HFP 推成不可写的 2^252。采用 SAS/ReadStat 向零截断（小于1 ULP），所有原始字节仍可访问。ADR 002 和最大指数完整fraction读写回归固定此行为；独立向量由精确 Fraction 决定截断方向。此前最近舍入的进度记录是历史状态，本决策为最终契约。

## S6 本地交付完成（2026-11-05）

C15 d4d4af2：可复现CI入口、固定版本/依赖、离线和联网任务分离、源包过滤、公共API签名，
并隐藏reader/writer/输入输出状态字段以保护不变量。27组+全部离线集成与独立消费方通过。
干净Git archive d4d4af23636592c4d4b6d8fb9d8f5ed9cd7135a0 在无构建缓存情况下完整复现，
两家oracle与三份真实文件均通过；日志与方法已归档。offline/real两条demo实测成功。

C16为用户使用文档、许可证/第三方声明、比赛一页说明、完整提交审计和最终交接。
本地交付16笔有效commit，最后hash由最终回复提供。远程发布没有执行；官方历史归档403、
GitHub Actions未运行是明确的外部未验证项，不计为通过。若恢复工作，先读 handoff.md。

## 发布收尾：证据归档（2026-11-05）

按用户确认冻结P0及基线1516dfd；原有16次提交不重写。找回C16完整缓存日志与摘要，
核对完整HEAD和日志末尾JSON一致，原样归档docs/evidence/c16/并登记SHA-256。
C15原始摘要单独保留，完整原始stdout未找到，不补造；旧docs/clean-reproduction.json不变。
这一提交只补验收审计资料。下一步调查官方固定工具链安装；CI与发布动作等待安装证据。

## 发布收尾：固定版本全新安装（2026-11-06归档）

原403来自安装器用moon构建工具版本构造归档键；改为对应moonc版本0.10.15+943464bfa，
官方原生包和core均可全新下载。保留原生包官方SHA-256与core首次HTTPS下载摘要的来源区别。
SDK身份仍是moon0.1.20261012/748b63c与moonc v0.10.15+943464bfa，P0无变更。

2026-11-05 23:05—23:11（UTC+8）同机隔离运行完整通过：开发HOME隐藏、无旧SDK与oracle、
新prefix、新venv、无下载/pip/构建缓存复用、三份语料重新下载。冻结C16的27组测试、全部
离线集成与两家oracle、620,612单元格及元数据均通过。DNS与可执行位两次失败单独归档，
未复用失败SDK。详见toolchain-installation.md和evidence/independent-install/。

这证明同机隔离用户空间的全新安装；共享宿主内核与基础OS，不冒称第二台机器。
原C15/C16验收记录不改写；CI配置、版本/制品和远端执行为后续阶段，未push、发布或提交赛事。
