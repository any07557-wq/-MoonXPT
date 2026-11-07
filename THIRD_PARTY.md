# 来源与许可证

MoonXPT 自有源码使用 MIT。二进制布局与算法根据 SAS 公开规范独立实现，没有
复制 ReadStat、Python xport 或 R foreign 的解析/数值源文件。

| 来源 | 使用方式 | 许可/边界 |
|---|---|---|
| SAS XPORT V5/V6 layout（October 2021 PDF） | 布局和测试向量依据 | 文档不再分发；SAS 为其权利人的商标 |
| MoonBit core 0.10.15+943464bfa | 产品依赖的标准库；没有 vendor 源码 | Apache-2.0，随本仓库保留许可证与 NOTICE 副本 |
| ReadStat / pyreadstat 1.3.7 | 仅开发期独立输入/对照 | ReadStat MIT；pyreadstat Apache-2.0（已核对安装元数据）；不被产品包导入 |
| Python xport 3.6.1 | 仅开发期第二实现家族 | MIT；pandas构造器适配单独留痕，不改格式算法 |
| pandas/numpy 等 | 仅 oracle 开发环境 | 已安装元数据的许可表达式与版本见 docs/references.md；不打包发布 |
| R foreign | 只列作参考，未安装、未运行 | GPL 源码未复制，不算验证通过 |
| CDC/NCHS NHANES | 数据交换兼容性演示 | 只下载并校验、不在 Git/包中再分发；清单见 tests/corpus.json |
| 小夹具及常量 | 自有数据经独立工具生成 | 生成脚本、版本、用途和 hash 全部记录；数据并非调查受试者记录 |

MoonBit 安装包的 CREDITS 另列 Binaryen（Apache-2.0）、TCC（LGPL）和 simdutf（MIT）
等可选工具链组件。本项目不分发编译器安装包；其原始说明保存在
`licenses/MoonBit-toolchain-CREDITS.md`，不得据此推断所有组件都链接进本 CLI。
当前本地发布准备以源码包为准，未公开发布任何原生二进制。

Source: CDC/NCHS。原始资料可免费从 CDC 网站取得；本项目及引用不代表 CDC、HHS
或美国政府背书。数据使用遵守[协议](https://www.cdc.gov/nchs/policy/data-user-agreement.html)：
用于统计报告/分析，不尝试身份识别、识别信息链接或重识别方法研究。
另见 [CDC materials policy](https://www.cdc.gov/other/agencymaterials.html)。

访问记录与全部一手链接见 docs/references.md；完整下载/安装记录和验证脚本位于完整源码包。
开发依赖和数据不被本项目 MIT
许可证重新授权；没有伪造来源、实测结果或外部许可证授权。
