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
