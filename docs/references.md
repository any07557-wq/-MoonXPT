

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
- MoonBit core LICENSE/NOTICE 和工具链 CREDITS 直接从已验证的固定版本复制到 `licenses/`。此前因错误使用 `moon` 版本构造归档地址而出现 HTTP 403；修正为 `archive_version` `0.10.15+943464bfa` 后，官方 SDK/core 重新下载和同机隔离用户空间安装均通过。SDK 官方归档 SHA-256 已校验；core 摘要为下载后记录值，不是官方独立发布的摘要。干净 Git archive 的构建未复制缓存，结果见 `clean-reproduction.json`。第二台机器及远端 CI 尚未验证。完整过程见 [toolchain-installation.md](toolchain-installation.md)。
- 赛事入口复访可达但未返回可读十一月规则；继续沿用“不声称十一月截止日期”的限制。
