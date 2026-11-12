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

## 发布收尾：外部验收准备（2026-11-06）

用户确认第二台机器和GitHub仓库均尚未配置，尚不能执行独立主机/远端CI验收。
CI接入通用verify_release.py：提取已提交HEAD、全新SDK，offline/full分离，full使用新venv
和重新下载的hash固定语料；保存阶段日志、退出码、SDK回执、依赖与环境信息及SHA-256。
官方Action发布commit已只读核对，Python固定3.14.4，移除语料缓存，失败也尝试上传证据。
可用Git bundle移交完整提交历史后，在第二台机器执行同一入口，无需先push。
工作流语法及本地预演另行记录；没有外部实际运行，不标作通过。P0和历史证据保持冻结。

准备提交958f9fce15feeea0ee39f541faafad831af3db38已保存。actionlint1.7.12、工作流策略、
Python语法与失败状态/双流日志/拒绝覆盖检查通过。Git bundle完整19笔历史的本地克隆验证通过。
offline/full两次本地预演各自全新下载SDK，均在官方原生包传输阶段超过600秒上限，结果FAIL，
未进入构建、测试、oracle或语料步骤。没有复用旧SDK或放宽限制，原样归档失败、源提交、
环境、输入及hash；不能计为新CI入口完整成功，也不计为第二台机器/远端CI通过。

## 发布收尾：远端CI验收归档（2026-11-07）

只读取得GitHub Run42329267843/attempt1的原始run/jobs/artifacts、两个ZIP与完整日志。
被测commit0dc4b95e001bc86253926be66321eb0e0f71b4db，offline与public-corpus均success，
托管Ubuntu24.04/Azure与开发机WSL不同；新SDK、完整任务新oracle/语料均有回执。
27/27、620612单元格及声明元数据全部通过，实际最大ULP0，无请求项跳过。
ZIP与GitHub SHA-256匹配，13+19份包内manifest记录及Git源码身份核验通过。

归档到evidence/github-actions/run-42329267843/，增加只读离线重验工具。
旧C15/C16、两次安装失败和两次SDK下载超时不改写。原16笔基线与P0保持冻结。
本轮没有触发/修改工作流或追加push；接下来做独立AI发布审查，正式Tag/Release尚未创建。

## 发布收尾：独立AI审查完成（2026-11-07）

云端证据先归档到提交9a45c6ea28cfbfba1d6c9508b2d2b634ef04a8f0，再交独立上下文AI
只读审查。审查者另外读取GitHub API、重验ZIP和20份工作流日志，确认技术验收证据成立，
未确认支持范围内的核心实现阻断缺陷；正式Release仍需统一CLI/模块版本并生成验证两类制品。
repository及Mooncakes身份为包发布待办，wheel摘要固定属于非阻断的长期复现改进。

原审查正文与来源登记evidence/release-review-20261107/，处理表见release-review-2026-11-07.md。
已澄清README：只有--rows提示NAME不区分大小写，--member仍精确匹配；P0行为不变。
未生成正式制品、未创建Tag/Release、未push或触发CI，没有发布Mooncakes或提交赛事。

## 发布阶段A：产品版本统一（2026-11-07）

模块与公共消费方原已为0.1.0，CLI帮助从0.1补齐到0.1.0；README、兼容性及待发布说明
明确产品版本。仓库examples是同一模块下的包，依赖根版本；消费方示例保持@0.1.0。
现有CLI集成检查比较实际横幅与根模块版本，研究脚本User-Agent也统一为0.1.0。
仅改变产品标识，不修改格式引擎、SAS来源元数据、schema或工具链版本；原历史快照不变。
离线完整检查27/27与全部集成通过；release构建与实际帮助首行0.1.0通过，输出另存。
接下来从实际提交生成两类候选包核对版本，不将其计为正式Release。

版本统一源码提交f1230b64e991ad94ba5455483665c6c4c387f77e。分别生成0.1.0库候选包
（236文件）与完整源码候选包（268文件），包内模块、当前CLI及说明一致；各自解压后
release构建、实际0.1.0横幅和ORACLE=4检查均通过。日志、版本矩阵、清单与摘要归档
evidence/version-unification-20261107/。两份ZIP留在本地独立缓存目录，旧包与旧证据不覆盖。
阶段A完成；R2最终制品验收、R3仓库元数据/命名空间仍待后续处理。没有push、触发CI或发布。

## 发布阶段B：两类最终制品准备（2026-11-07）

模块readme改为专用README.library.md，并填入已知公开repository；命名空间确认仍待发布阶段。
库包过滤开发证据和工具，保留用户契约、测试夹具及许可；完整源码保留全部已提交文件，
补Git bundle以离线恢复截至选定提交的完整历史。新打包器生成同源两类ZIP、内部清单与
外部SHA256SUMS，独立验证器将从ZIP进入隐藏开发HOME的隔离用户空间重装SDK/oracle，
执行源码完整对照及库包独立消费验证。P0程序源码与格式行为没有改动。

阶段B源码提交2cddd31bb8b88648f619969dbb4fe195051735b4：完整源码294文件/837463字节，
库包67文件/78298字节，两包生成于dist/0.1.0/stage-b/。Git bundle恢复29次完整提交及相同HEAD，
原16笔基线和全部Git跟踪文件核验通过。许可/夹具与源码一致，包内无构建缓存或SDK/原语料。
同机隔离隐藏开发HOME，全新SDK/core、venv/oracle、重新下载语料后，源码27/27及620612
单元格/元数据0ULP通过；库包另27/27、release CLI往返和仅依赖解压库的消费方通过。
逐阶段日志、清单、最终SHA-256及篡改拒绝记录归档evidence/artifacts-20261107/。
额外复打包发现Git bundle压缩字节变化导致源码ZIP摘要不同，Git身份/历史与源码内容相同；
库ZIP复打包字节相同，观察如实记录，不承诺源码ZIP逐字节确定性。最终校验针对保留的原ZIP。
R2制品验收关闭，R3repository补齐、命名空间待确认；未push、创建Tag/Release、发布或提交赛事。


## v0.2.0边界增强（2026-11-11至11-12）

新分支work/v0.2.0-boundary，开始HEAD bad7ec0；不改v0.1.0标签、历史或旧证据。原有
未跟踪申报书保持原样。C01 c65e673完成实际审计与ADR；C02 6c2732d完成共享尾部resolver
和B01–B20（47/47）；C03 7db9373完成全局成员链和M01–M23（70/70）；C04 fcc38e0完成
新策略、Writer风险、CLI/JSON和A01–A18（78/78）。原27组及所有离线脚本没有更改断言。
C05 98a249d仅准备SAS程序、执行门禁和MoonXPT合成输入，用户确认无合法环境，状态blocked。

C06 ReadStat/pyreadstat一家族与Python xport另一家族的双向矩阵、4成员正常输出、28种缺失
低层向量及620612单元格回归均已实际通过。便利reader空白行丢失、字符裁剪、缺失归一和
ReadStat多成员限制单列。305份旧材料/测试核对不变，五类CI本地配置并lint，但未push或
运行新远端CI。接下来把门禁代码提交后做精确commit的clean checkout，再追加最终回执。

C06后续发现并补齐文件输入逻辑原点、资源上限不能消除格式歧义两类回归。新增3组，
当前81/81、全部旧集成、独立矩阵、真实语料重新通过，先前失败日志保留；最终clone待追加。
