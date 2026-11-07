# v0.1.0独立AI发布审查

原审查结论：本地与独立云端的核心技术验收证据成立；当时不创建正式Release。
阶段C处理更新：R1/R2已关闭，GitHub v0.1.0正式发布；[发布证据](evidence/release-20261107/README.md)
与原审查分开归档。Mooncakes尚未发布。
审查提交为 `9a45c6ea28cfbfba1d6c9508b2d2b634ef04a8f0`，云端被测提交为
`0dc4b95e001bc86253926be66321eb0e0f71b4db`。原16笔与P0冻结基线不变。

审查由独立上下文的只读AI代理执行，没有继承本轮对话结论。
[审查原文](evidence/release-review-20261107/independent-review.md)按收到的正文归档，
行号对应审查提交；[记录与摘要](evidence/release-review-20261107/review.json)登记来源及状态。
主代理处理结果在本文单列，不修改原审查结论。

## 核验结果

审查者独立读取GitHub API，并重验原ZIP、解压文件、manifest、输入及源码身份，确认
Run42329267843/attempt1两类job成功；27/27、620612单元格及声明元数据、最大ULP0。
20份工作流日志与日志ZIP逐字节一致。许可、夹具来源、Git历史和P0冻结范围未发现明确阻断。
未确认已声明支持范围内的核心读写、数值或交换实现有发布阻断缺陷。

这是只读审查与已有证据复核，没有重跑全套产品测试、安装SDK或触发工作流。
源码审查不构成所有输入均正确的证明。三份真实NHANES输入都是数值列；字符、CP1252、
多成员及特殊缺失由独立小夹具/底层适配/向量覆盖。云端本次没有跑benchmark，百万行
release性能结果仍属于先前的本地实验。人工指定的第二台SSH主机未另行验证。

## 发布前待关闭项

| ID | 范围 | 事实及处理状态 | 下一步 |
|---|---|---|---|
| R1 | GitHub正式Release | 阶段A已统一为0.1.0；27/27、本地release及两个解压候选包的版本检查通过，见[证据](evidence/version-unification-20261107/README.md) | 最终候选与制品绑定验证继续在R2跟踪，原审查正文保留 |
| R2 | GitHub正式Release | 阶段B从2cddd31生成并隔离验证两类最终制品；阶段C获授权后创建精确源码annotated tag、完成标签完整CI并发布，7份附件回下载校验通过 | 已关闭；[制品](evidence/artifacts-20261107/README.md)与[发布](evidence/release-20261107/README.md)证据分别保留 |
| R3 | 最终包元数据与Mooncakes | repository已补；登录名any07557-wq，用户确认后续使用此命名空间；派生预备包检查通过但未发布 | 完整仓库迁移、最终打包及registry权限/版本复核仍待进行；[准备说明](mooncakes-preparation.md) |
| R4 | 文档，非阻断 | --rows与--member大小写规则措辞不清；本轮已澄清README | 没有改变CLI或P0行为 |
| R5 | oracle长期复现，非阻断 | 固定版本而未锁wheel摘要；保留为后续改进 | 不否定本次已发生验收，也不增加产品运行依赖 |

R3的账号/命名空间确认是Mooncakes门槛，不是GitHub源码技术验收失败。
R2须明确区分 `moonxpt-0.1.0.zip` 与 `moonxpt-0.1.0-source.zip`：前者服务集成，
后者含tools、CI、测试、文档和许可证供审查。库包README需指明验证脚本依赖完整仓库，
避免留下指向被过滤tools的本地链接。旧ZIP不能重新命名后直接当成最终制品。

## 后续执行边界

原审查及当时的README澄清保持原样。后续R1/R2关闭使用追加提交，原失败记录与云端
证据保留；最终制品已绑定2cddd31，精确标签由Run42361761773验证，不借用旧run作证明。
GitHub已按用户阶段C授权正式发布；Mooncakes和赛事提交分别处理，均未执行。
十一月官网及实际报名表已复核，事实及尚未取得的正式章程/截止通知见
[赛事要求](monthly-contest-202611.md)。既有AI生成技术说明不能直接作为表单申报书。
