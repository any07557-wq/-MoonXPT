# 阶段C：v0.1.0正式发布验收

2026-11-07，GitHub正式发布完成。按用户阶段C授权执行；Mooncakes及赛事提交不在本次
实际发布范围内。原16笔冻结开发历史、既有失败材料和阶段A/B证据均保留。

## Push、标签与CI

- main从0dc4b95快进至aa56905542eac189c7d18753444d6eaa97ecf719。最新两笔依赖4笔
  先前未推送提交，正常push一并传输了6笔，不重写历史。
- main push的Run42361511304成功，offline通过；public-corpus按条件跳过，不计作完整语料通过。
- 创建并推送annotated tag `v0.1.0`，tag对象
  `51ab97700bdaf15e225f432ec1bf27c94dc70a8f`，peeled源码
  `2cddd31bb8b88648f619969dbb4fe195051735b4`。后者是两包实际来源；aa56905仅追加阶段B证据。
- 在精确标签上手动触发real_corpus=true的
  [Run42361761773](https://github.com/any07557-wq/-MoonXPT/actions/runs/42361761773)，
  offline/public-corpus均成功。27/27、6项离线入口、两个oracle家族、620612单元格及声明元数据，
  最大ULP0。原API/ZIP/日志、manifest与Git输入逐字节复核通过，见[独立归档](../github-actions/run-42361761773/README.md)。

没有修改workflow配置，没有移动原冻结基线。main后续发布状态文档提交不是v0.1.0源码。

## 正式Release与制品

[MoonXPT v0.1.0](https://github.com/any07557-wq/-MoonXPT/releases/tag/v0.1.0)
已发布，非draft、非prerelease。发布使用已有远端annotated tag及阶段B保留的实际ZIP。

| 主要制品 | SHA-256 |
|---|---|
| moonxpt-0.1.0.zip | 93df9b777bdb075dab1213fdf71fdef3fc09b515dd1676b3d635d8205d9962f1 |
| moonxpt-0.1.0-source.zip | 853064a112ad766635fc8521c18a2c5993fc09c7697cfb191a2523371e911b13 |

另附SHA256SUMS、release-manifest、两个inventory及validation证据ZIP，共7个手动附件。
全部从已发布Release重新下载，大小、SHA-256与本地保留记录及GitHub摘要一致；
[API原件](release.json)、[回下载核验](release-verification.json)、[发布命令输出](release-create.log)
与[发布前检查](publication-preflight.json)分开保存。

源码ZIP含tools、CI、测试、文档、许可证、旧证据及恢复截至2cddd31的29次历史的Git bundle；
库ZIP为67个文件的消费制品，不能代替完整评审源码。源码包内待发布文字属于构建时快照，
不为更新发布状态而重打包。重新压缩Git bundle可能改变ZIP字节，原观察及精确制品验收
继续见[阶段B](../artifacts-20261107/README.md)。GitHub自动生成源码下载不含附加Git bundle。

验证证据ZIP保存阶段B新安装与本次标签CI原件，不含SDK、venv、构建缓存或真实语料。
Linux x86_64 native支持范围及既有兼容边界不变，没有新增云端benchmark结论。

## 独立处理的事项

- Mooncakes：用户确认后续目标any07557-wq/moonxpt；库范围派生预备包27/27、构建及消费通过，
  未发布。main与GitHub附件仍保留any07557/moonxpt；[完整迁移待办](../../mooncakes-preparation.md)。
- 十一月月赛：已读取当前官网源码及实际表单配置；正式章程全文未取得，官网具体截止仍待通知。
  表单窗口及本人申报书要求见[复核说明](../../monthly-contest-202611.md)。未代填或提交。

本目录manifest.json登记归档文件SHA-256，不登记自身；不包含产品ZIP主体，避免递归归档。
