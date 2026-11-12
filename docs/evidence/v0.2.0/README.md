# v0.2.0开发证据索引

原v0.1.0材料保留原路径，本目录只登记新开发证据。

| 阶段 | 状态 | 目录 |
|---|---|---|
| C01 | passed | c01：实际审计、原离线27组、规范来源及保护清单 |
| C02 | passed | c02：B01–B20、47/47与原集成 |
| C03 | passed | c03：M01–M23、70/70、含首次legacy trim回归失败记录 |
| C04 | passed | c04：A01–A18、78/78、14份fixture摘要与CLI回执 |
| C05 | blocked | c05：仅准备SAS程序、MoonXPT输入；S01–S14未由SAS执行 |
| C06 | prepared_not_verified（最终克隆待追加） | c06：双向矩阵、真实语料、资源、保护、CI静态检查及raw ZIP |

新目录有各自SHA-256或ZIP内文件清单；日志原始空白/CSV字段不为lint改写。
c06 raw ZIP中的BUNDLE-MANIFEST.json是归档新增元数据，不冒称原测试生成。
初次interop检查的空label None/空字符串差异失败原样保留；仅规范化该元数据表示，
未裁剪观测字符串、扩大数值容差或跳过失败成员。

完整结论和复现命令见../../validation-report-v0.2.0.md。最终精确commit的clean checkout
完成后，会以新的独立目录追加，不覆盖此前阶段结果。


## 最终状态（2026-11-12）

前表保留各阶段当时状态。R14已从69abb7dfa7b44dfc7dfc7d3e4e8b89addb50a48d
干净克隆通过，C06现为passed；81/81及其余核心门槛完成，SAS仍blocked。结论为
READY_WITH_SAS_VALIDATION_BLOCKED，见[最终回执](final-20261112/README.md)。
