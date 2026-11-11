# MoonXPT 0.1.0版本一致性

阶段A目标：当前产品版本统一为 **0.1.0**，标签命名为 **v0.1.0**。
moon.mod的version字段是产品版本依据；阶段A原始证据保持不变。
阶段C已创建v0.1.0标签及GitHub Release，Mooncakes尚未发布。

| 检查对象 | 当前产品版本或规则 |
|---|---|
| 模块any07557/moonxpt | moon.mod：0.1.0 |
| CLI帮助首行 | MoonXPT 0.1.0 — SAS XPORT V5 (native) |
| README | 当前产品版本0.1.0，并链接正式Release |
| 仓库内examples/scan、examples/write | 同一模块下的包，继承根moon.mod，无独立版本 |
| 外部消费方示例 | docs/reproduction.md与tools/test_consumer.py均依赖any07557/moonxpt@0.1.0 |
| 库候选ZIP | moonxpt-0.1.0.zip，包内根模块、CLI和说明使用0.1.0 |
| 完整源码候选ZIP | moonxpt-0.1.0-source.zip，相同根版本，另含tools、CI、测试及文档 |
| 发布与兼容性说明 | CHANGELOG.md的0.1.0发布条目；docs/compatibility.md注明适用0.1.0 |

现有CLI集成检查会将实际--help首行与moon.mod比较，防止模块升级后遗漏CLI横幅。
本次仅修正产品版本标识；SAS XPORT V5、CSV/JSON schema_version=1、输入文件中的SAS
来源版本、MoonBit SDK、oracle和GitHub Action的版本按各自含义保留。
历史审查所记的0.1横幅、日志、归档快照和旧本地ZIP也保持原样，不能改写成新版证据。

## 源码与库候选包

本阶段从版本统一后的实际提交生成两个用于版本检查的候选ZIP，使用新目录，保留旧包。
核对ZIP根moon.mod、当前CLI源码、README、发布说明和兼容性版本，并解压构建CLI验证
实际横幅。候选包的source_commit、清单/摘要与输出另行归档，不把旧包改名当作新制品。

这些包用于阶段A版本核对。完整源码/库制品的最终清单、README链接、公共消费方、
发布元数据及最终候选复现仍属于阶段B/R2；本次候选包不因此被声明为正式Release制品。
标准库包过滤tools和.github，库包中的开发验证命令需使用完整仓库。
阶段B模块readme指向README.library.md，库包只保留该入口与指定用户文档；完整源码
仍保留README.md、CHANGELOG、全部工具/证据和Git历史，具体见[打包说明](artifacts.md)。

## 验证与后续状态

本地执行离线tools/check.py，覆盖格式、静态检查、27组、构建、CLI及公共消费方，
另检查release构建与两个解压候选包的版本输出。以上检查均通过，
[原始日志、版本矩阵及候选包摘要](evidence/version-unification-20261107/README.md)已归档，
候选源码固定于f1230b64e991ad94ba5455483665c6c4c387f77e。
Run42329267843仍只证明其原被测提交，不计为验证了此次版本整理。
R1的产品版本标识在本阶段处理，最终候选及制品绑定验证继续由R2跟踪；Mooncakes的
repository与命名空间/版本确认由R3跟踪，原P0功能保持冻结。

阶段B已完成[最终制品验收](evidence/artifacts-20261107/README.md)，不再使用阶段A候选包
作为发布输入。最终库包入口为README.library.md，完整源码含全部已提交文件及Git历史；
两包版本0.1.0，source_commit固定2cddd31bb8b88648f619969dbb4fe195051735b4。

阶段C的annotated tag v0.1.0指向上述制品源码提交，而不是其后的证据文档提交。
GitHub Release已发布且全部附件回下载校验通过，见[记录](evidence/release-20261107/README.md)。
已发布ZIP中的README/CHANGELOG是打包时的历史快照，正文当时为待发布；正式状态以
Release及本次追加证据为准，不为更新状态而替换附件字节。Mooncakes新命名空间迁移独立处理。

## v0.2.0开发目标（2026-11-11追加）

上述表格与证据保留0.1.0历史。当前开发分支模块与CLI横幅改为0.2.0，README注明未发布，
不创建同名tag或制品发布。SAS来源version、JSON schema_version、SDK版本不随产品版本改写。
命名空间继续any07557/moonxpt，既定Mooncakes迁移在另一任务处理。本次原公共消费方工具
保留0.1.0依赖声明并通过workspace编译，用于证明调用签名兼容，不声称registry存在0.2.0。
