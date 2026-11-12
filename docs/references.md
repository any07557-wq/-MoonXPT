

# 来源、版本与使用条件

所有访问日期为 2026-11-04。

- [SAS V5/V6 layout](https://www.sas.com/content/dam/sasdam/documents/20260302/record-layout-of-a-sas-version-5-or-6-data-set-in-sas-transport-xport-format.pdf)：实际下载，PDF 内注明 October 2021，SHA-256 c7c82e664651fdf7c74134b3536af2ba1c5c2834ca91ea427e886eea0b118ac3。用于布局和独立数值向量；不再分发规范全文或其 C 算法。
- [ReadStat](https://github.com/WizardMac/ReadStat)，dev 查询快照 8ce32a11c248225dd4ccaccbcadd24214c5da46f；MIT。阅读 reader 行为，验证工具 pyreadstat 1.3.7 自带的 ReadStat 与该源码快照不视为同一构建版本。
- [pyreadstat API](https://ofajardo.github.io/pyreadstat_documentation/_build/html/index.html)，实际安装 1.3.7（Python 3.14）。read_xport 签名无 user_missing 参数。S0 实测三份文件，关闭日期转换。只作为一个 ReadStat 家族。
- [Python xport](https://github.com/selik/xport)，3.6.1，MIT；独立纯 Python V5/V6 多成员实现。其旧版 pandas 构造器与 pandas 3 不兼容，tools/xport_compat.py 仅适配 Series 构造器，不更改 XPORT 算法。验证结果与限制另行记录。
- [R foreign read.xport](https://stat.ethz.ch/R-manual/R-patched/library/foreign/html/read.xport.html)，GPL；未安装，不计为已运行验证，不复制实现。
- [NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overview.aspx?BeginYear=2017)：公开使用统计数据；[CDC 使用条件](https://www.cdc.gov/other/agencymaterials.html)、[NHANES 数据用户协议](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overview.aspx?BeginYear=2017)须遵守禁止识别个人及数据使用要求。语料仅下载到忽略的缓存，不打包再分发，来源页和 hash 见 tests/corpus.json。它们不受本项目代码许可证重新授权。
- [MoonBit 构建文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html)、[FFI](https://docs.moonbitlang.com/en/latest/language/ffi.html)：实际工具链 moon 0.1.20261012 (748b63c)、moonc v0.10.15+943464bfa；native 后端优先。一个猜测的 native-cli-quickstart URL 返回 404，未作为依据。
- [2026 赛事](https://moonbitlang.github.io/Hackathon2026/)：没有核实十一月赛程，不编造截止时间。


## 2026-11-05 交付复核

- [NCHS Data User Agreement](https://www.cdc.gov/nchs/policy/data-user-agreement.html) 已实际打开；之前overview链接仅为来源入口。统计使用、禁止识别和可识别链接等约束由 README/THIRD_PARTY 明示。 [CDC materials policy](https://www.cdc.gov/other/agencymaterials.html) 的来源标注、免费可获取与不背书约定已列明，不再分发原始语料。
- 已核对已安装 wheel 元数据：pyreadstat 1.3.7 为 Apache-2.0；ReadStat 为独立上游 MIT；xport 3.6.1 MIT。pandas 3.1.0 BSD-3-Clause；numpy 2.5.4 表达式 BSD-3-Clause AND 0BSD AND MIT AND Zlib AND CC0-1.0；narwhals 2.28.0 MIT；python-dateutil 4.0.0 BSD-3-Clause；tzdata 2026.6 Apache-2.0；setuptools 80.10.2 MIT。这些开发工具不进入产品依赖。
- MoonBit core LICENSE/NOTICE 和工具链 CREDITS 直接从已验证的固定版本复制到 `licenses/`。此前因错误使用 `moon` 版本构造归档地址而出现 HTTP 403；修正为 `archive_version` `0.10.15+943464bfa` 后，官方 SDK/core 重新下载和同机隔离用户空间安装均通过。SDK 官方归档 SHA-256 已校验；core 摘要为下载后记录值，不是官方独立发布的摘要。完整源码包的 `docs/clean-reproduction.json`、`docs/toolchain-installation.md` 及 `docs/evidence/` 分别保留历史结果、安装过程与后续云端证据；库包不附开发验证归档。
- 赛事入口复访可达但未返回可读十一月规则；继续沿用“不声称十一月截止日期”的限制。
# v0.2.0新增核对（2026-11-11）

以下为新版本访问记录，原v0.1.0条目与访问结论保留。

- [SAS官方TS-140](https://support.sas.com/techsup/technote/ts140.pdf)：现行文档Last update October2021，28页；pp3–7为80字节记录、MEMBER/NAMESTR/OBS与空格填充，pp11起为数值。11-11通过PDF阅读器访问；直接下载TLS失败，不伪造新PDF hash。
- [SAS官方EOF问答](https://www.sas.com/zh_tw/industry/government/accessibility/accessibility-compliance.html)：页面所含XPORT FAQ的EOF问答说明W<80、全字符且最后观测全空格的丢行风险及PROC COMPARE建议；网页位置异常但内容及官方域已实际核对，未将建议冒充本次SAS执行。
- [ReadStat reader](https://github.com/WizardMac/ReadStat/blob/8ce32a11c248225dd4ccaccbcadd24214c5da46f/src/sas/readstat_xport_read.c)、[writer](https://github.com/WizardMac/ReadStat/blob/8ce32a11c248225dd4ccaccbcadd24214c5da46f/src/sas/readstat_xport_write.c)：固定commit已下载，xport_read_data与写出padding逻辑核对；源码hash见evidence/v0.2.0/c01/sources.json。pyreadstat bundled构建的身份另列，不能直接说成此commit。
- [Python xport3.6.1](https://github.com/selik/xport)：已安装固定发行包的v56.py SHA-256为20b5e2dd8cba9fb57f4a785933ec4fcf8668807e8d828f6b9c4803c1611085ba；Observations在空白行终止并rstrip字符、Member/Library处理多个成员。pandas构造器适配不改变格式算法。与ReadStat是两个家族。

关键规则、MoonXPT决策及B/M/A/R测试ID见[ADR-003](adr-003-v5-boundary-resolution.md)。


## v0.2.0实际oracle构建核对（2026-11-12追加）

- [pyreadstat1.3.7固定源码](https://github.com/Roche/pyreadstat/tree/e6e23bc0021875f35fccc3c2707c3e5151c130bb)：11-11通过官方GitHub API核对tag commit与vendored readstat.h/reader/writer blob。它的reader SHA-256为11c18b92a8db0daca92a965b50fe20edc88903c4c14a54235d79a93b6ce5ce71，与上游8ce32a1不同。writer摘要相同，但不能据此说成运行过上游commit的独立构建。
- 实际vendor缺少宽空白尾行补丁，两个固定便利reader实测都会丢失80字节全空白观测；上游源码中的修复没有用于替代实际运行。动态模块、适配器、全部固定依赖版本及SHA记录在新c06证据。
- Python xport的MemberHeader/Namestr低层API提供position、width、标签和format/informat；其DataFrame Series可能丢失这些属性，故未用Series属性作元数据真值。低层ibm_to_ieee另验28种缺失，字符rstrip/NaN归一限制不隐藏。

C06不新增运行时依赖，两个oracle家族的源与许可仍按原THIRD_PARTY.md保留；测试数据为自有合成内容，真实NHANES文件不入Git或发布包。
