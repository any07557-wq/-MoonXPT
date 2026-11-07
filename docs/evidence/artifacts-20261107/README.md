# 阶段B：0.1.0最终制品验收

2026-11-07，结果PASS。两类制品均从确定提交
`2cddd31bb8b88648f619969dbb4fe195051735b4`（tree
`f42ca4a10bce4b3fdce52becb6db726ec44799a2`）生成。
发布说明与包元数据版本为0.1.0，本轮没有创建Tag/Release或发布到Mooncakes。

## 保留的实际制品

本地目录：`dist/0.1.0/stage-b/`。本证据目录保留清单、摘要和结果，不嵌入源码ZIP，
避免后续源码包递归包含前次源码包。SHA256SUMS可在该制品目录执行`sha256sum -c SHA256SUMS`。

| 制品 | 用途 | 文件数 | 字节数 | SHA-256 |
|---|---|---:|---:|---|
| moonxpt-0.1.0-source.zip | 全部已提交源码/工具/CI/测试/文档/原证据，附完整Git bundle | 294 | 837463 | 853064a112ad766635fc8521c18a2c5993fc09c7697cfb191a2523371e911b13 |
| moonxpt-0.1.0.zip | 用户直接集成的库源码、专用README、用户契约/夹具及许可 | 67 | 78298 | 93df9b777bdb075dab1213fdf71fdef3fc09b515dd1676b3d635d8205d9962f1 |

每包附ARTIFACT.json与PACKAGE-MANIFEST.json，分别登记角色/源码身份和逐文件摘要。
外部完整清单见source-inventory.json与library-inventory.json；生成结果见release-manifest.json。
库包不含tools、.github或docs/evidence，也不使用完整源码README冒充库使用说明。
完整源码包的Git bundle在隔离环境恢复出同一HEAD和29次完整提交，包含最初16笔冻结历史；
所有已跟踪文件与恢复的Git对象逐字节一致。后续验收文档提交不在该源码提交范围内。

## 许可证、缓存与完整性

LICENSE、THIRD_PARTY、core LICENSE/NOTICE、工具链CREDITS和夹具来源清单与该Git提交
逐字节相同，4份小夹具hash全部匹配。记录见isolated-verification/integrity-and-licenses.json。
两包不含.git工作目录、构建缓存、venv、下载SDK/oracle、dist输出或真实调查数据；完整源码
保留的旧日志及小型原artifact ZIP属于审查材料。库包README的本地链接均指向包内文件。
本核对确认许可文件和来源声明的保留，不对未分发的工具链二进制作许可推断。

negative-checks/保留两个预期拒绝用例：ZIP字节被改、以及外层ZIP摘要更新但内部文件被改。
二者均在联网安装前以非零退出拒绝。原始日志与checks.json保持原样。

## 从两个实际ZIP进行的干净验证

使用同机bubblewrap隔离用户空间，开发HOME隐藏，基础OS/内核及DNS/代理共享。
前置检查无旧SDK路径、oracle模块或源码构建缓存；重新下载并校验SDK/core，安装全新venv，
从PyPI无缓存安装固定oracle，重新下载并验hash三份语料。新SDK供本轮两个独立解压树使用。
这不是新的远端CI，也未另开一台物理机器；没有把旧云端结果作为本轮制品测试结果。

| 对象 | 实际验证 |
|---|---|
| 完整源码ZIP | Git历史恢复和文件一致性；格式、静态检查、27/27、构建、6项离线集成、ReadStat/xport及三份语料全链路，620612单元格/元数据通过，最大ULP0，无跳过 |
| 库ZIP | 静态检查、27/27、release构建、0.1.0帮助横幅、inspect/export/write再inspect共4行；公共API消费方仅依赖解压库目录并通过 |

实际阶段退出码、SDK和依赖回执、全部stdout/stderr见isolated-verification/。
verification.json及process.json均PASS/退出码0。库运行不需要oracle；辅助验证脚本从完整源码
取得，在库外运行，没有回到开发目录取产品代码。三份真实NHANES均为数值列；字符、CP1252、
多成员及28缺失另由独立小夹具/向量覆盖；未执行benchmark。

## 再打包观察与边界

另用同一提交复打包一次：库ZIP字节一致，源码ZIP因Git bundle重新压缩而不同，变化仅限
bundle及引用它的两份生成元数据。两份bundle恢复的HEAD、29次历史及Git跟踪内容一致。
rebuild-check.json和second-build-manifest.json保留这次观察与两个摘要，未将最初的逐字节
一致性断言失败写成成功。最终SHA256SUMS绑定上表保留的第一份实际ZIP，不承诺重新打包
或跨Git版本产生相同压缩字节；语义/历史复现与制品字节校验分别核对。

源代码、库元数据的repository字段已补齐；Mooncakes账号/命名空间控制权及版本占用仍需
发布阶段确认。阶段B完成不代表已发布。完整过程见[打包说明](../../artifacts.md)。
