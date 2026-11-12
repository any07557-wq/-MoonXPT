# V5 兼容性矩阵（2026-11-04）

适用产品：MoonXPT **0.1.0**；版本统一阶段不改变以下功能、精度或兼容性承诺。

本表区分规范/字节向量、独立实现与真实样本证据。唯一承诺运行后端是 Linux x86_64 native；其他平台未验证。代码不依赖 oracle 运行。

| 能力 | 实现及验证状态 | 证据与边界 |
|---|---|---|
| V5 库头、成员、OBS | 已实现/已验证 | 3 份 NHANES；ReadStat/xport 独立输入；保留原始元数据字节 |
| V8 | 明确拒绝 | version 诊断；不按 V5 解析 |
| 136/140 NAMESTR | 读取两者已验证；写出140 | 独立 ReadStat 派生布局向量；跨块单字节短读 |
| 名称、变量顺序与标签 | 已实现/已验证 | 8 字节名、40 字节标签；重复大小写名称拒绝；真实数据全列比较 |
| format/informat/hash/number | 已实现/已验证 | 明确字段属性；ReadStat DATE9./BEST12. 输入；真实描述符独立字节比较；不执行格式 |
| 存储位置/间隙/重排 | 已实现/向量已验证 | reordered-offsets.xpt；读写后所有物理字段字节比较；重叠/越界拒绝。常见 oracle 忽略 npos，不能证明非顺序布局互操作 |
| IBM 数值宽度2–8 | 已实现/独立向量已验证 | 64×7 编码与128个有理数向零截断解码；缩短宽度按规范截断；正负0、分数、边界、NaN/Inf 错误 |
| 数值范围与精度 | 已实现/已验证 | 正规化 HFP 非零最小2^-260，最大严格小于2^252；零写成正零。8字节 IEEE输入精确装入56位；读取按SAS/ReadStat向零截断，误差小于1 ULP；拒绝非规范未正规化fraction，原始读取仍可访问其字节。Python xport/SAS便利转换程序的高端编码限制更窄；本库保留原始 HFP 范围 |
| 28 种缺失 | 已实现/已验证 | .、._、.A–.Z；规范字节+Python xport低层 tag 验证，DataFrame NaN 不作为标记证据 |
| 原始字符与编码 | 已实现/已验证 | 全字段原始字节；ASCII/CP1252严格双向；未定义字节报编码错误；V5字符1–200字节；编码后超长拒绝 |
| 单/多成员、空成员 | 已实现/独立验证 | xport独立读4个输出成员；独立双成员输入；库writer可多成员，CLI每次写一个 |
| 物理对齐/截断/伪头 | 已实现/已验证 | 最后一块非80字节拒绝；失败候选有界回放；完整合法伪成员头默认诊断歧义 |
| 尾部歧义 | 显式策略/已验证 | 默认 Reject；逐成员行数提示保留短全空白行；TrimPadding选择最大合法padding并按验证头切成员，可丢歧义空白行。严格多成员也可能需 hints，文件没有编码行数 |
| 拉取/取消/资源限制 | 已实现/已验证 | 提前停止停止I/O，调用方关闭；字节/列/行/成员/分配限制；100倍合成行数导出和写入 RSS 证据 |
| CSV+JSON v1 | 已实现/已验证 | UTF-8、逗号、引号、CRLF/LF、内嵌换行、空串/空格、类型化缺失；未知版本/重复列/列数失败 |
| inspect/export/write | 已实现/完整链路验证 | 稳定JSON；未要求计数时null；stdout结果/stderr诊断；退出0/2/3/4；三份真实样本全链路 |
| 输出失败语义 | 已实现/已验证 | 默认不覆盖、路径空格/别名、独占stage、冲突回滚及恢复旧文件测试；机器崩溃跨文件原子性不保证 |
| 其他编码、SAS7BDAT、CPORT、外部值标签目录 | 不支持/不在本期范围 | 不猜测编码、日期或值标签；日期保留有限数值及format |

确定性：相同 schema/值/选项产生同字节；无来源时间时使用可注入的固定 DATETIME16。保留来源时间时按实际字段写出。reserved字段与描述符尾部规范化，存储间隙填空格，元数据头部填充重建；CSV往返不保证整个文件hash或 IBM 低有效位。

## v0.2.0开发阶段新增边界（2026-11-11）

上表保留v0.1.0历史结果。本节为未发布开发版本，不将旧云端run算作新版本CI。

| 能力 | 状态 | 证据/限制 |
|---|---|---|
| 单成员候选N/P与hint验证 | passed | B01–B20；共享resolver，字段间隙/重排及溢出检查 |
| 全局成员链 | passed | M01–M23；完整头/EOF图、候选缓存、成员/搜索/回放预算 |
| 新策略与报告 | passed | A01–A18；旧选项record与finish调用兼容，错误stdout保持空 |
| Writer已知短空白末行风险 | passed | 默认拒绝，显式allow及报告；宽空白行/空成员不误拒绝 |
| 非标准NUL兼容 | passed（本地合成fixture） | 默认不允许；仅opt-in，不声称SAS规范；独立工具结果在C06另验 |
| 非seekable结构分叉 | passed（限额内） | 小chunk通过，回放超限明确失败；不承诺任意长分叉常量内存成功 |
| ReadStat/Python xport新双向矩阵 | not_run | C06完成后追加实际证据；旧结果不替代 |
| SAS XPORT Engine双向 | blocked | 用户确认无合法环境/runner；C05仅准备，不以mock替代 |

API、CLI、JSON状态及迁移说明见[新边界契约](boundary-v0.2.0.md)。


## v0.2.0 C06互操作更新（2026-11-12追加）

本节更新上一开发阶段的not_run状态，不改v0.1.0表格或C04当时记录。

| 能力 | 状态 | 工具/证据及限制 |
|---|---|---|
| ReadStat家族双向单成员 | passed | pyreadstat1.3.7，实际vendor e6e23bc；普通数值、掩码及暴露元数据，c06/interop/result.json |
| ReadStat多成员 | not_supported_by_oracle | 实测4成员文件被当首schema读取为124行，未计作通过 |
| Python xport单/多成员双向 | passed（正常支持范围） | 3.6.1固定v56摘要；完整4成员，逐行逐列及低层metadata/tag；边缘输入另列 |
| 短/宽全空白末行 | not_supported_by_oracle（两个便利reader） | SHORT 2→1、FULLBL 1→0；MoonXPT严格解析与字节向量通过，不将oracle裁剪结果当真值 |
| 字符原始存储与tag | not_supported_by_oracle（便利DataFrame） | 全字符原始字节按作者向量；tag另由xport低层28种字节向量证明 |
| 旧真实语料新版本回归 | passed | 3份620612单元格及声明元数据，实际max ULP0；新c06结果与旧记录分开 |
| SAS双向 | blocked | 无合法SAS环境/runner，S01–S14没有实际执行 |
| 新远端CI | not_run | 五类job已配置并本地lint；未push，不继承v0.1.0云端结论 |

完整仓库的docs/validation-report-v0.2.0.md列出版本、方向、限制和复现命令；clean checkout
实际结果会在最终验收章节单独追加。
