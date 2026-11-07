# 最终交接（2026-11-05）

发布收尾状态更新：2026-11-07。原本地交付提交审计仍固定于C16。

项目路径：`/home/user/MoonBit_Program/MoonXPT`。开始状态为新建空目录，无基线 HEAD，
没有已有用户代码；所有下列提交属于本任务，作者使用用户提供的本仓库身份。

## 本地交付结果

- MoonBit V5流式库及inspect/export/write完整CLI；单/多成员，136/140描述符，字段偏移，
  28种缺失，ASCII/CP1252，原始字节与显式尾部策略，版本化CSV/JSON。
- 27组测试与6项离线集成入口（inspect/export/exchange/fixtures/malformed/consumer）；
  79截断、256变异、8定向结构错误，输出竞争回滚已实际验证。
- 三份NHANES人口统计/体检/实验室输入，620612单元格和已声明元数据完整比较，0 ULP实际差异。
  ReadStat与Python xport两个独立家族；特殊缺失不靠DataFrame NaN判相等。
- C15干净Git archive完整复现通过；代码无构建缓存拷贝，具体边界见 clean-reproduction.json。
- C16冻结基线的完整执行记录与摘要已在后续收尾中归档到 [evidence/](evidence/README.md)，保留C15原始摘要，不把环境复用当作独立安装。
  百万行合成导出与写入 RSS约2.5–3.1MiB，证据见 benchmarks.md。
- 发布收尾另有[全新安装验收](evidence/independent-install/README.md)：冻结C16源码、
  官方SDK/core、无缓存PyPI oracle与重新下载语料，完整检查通过且无跳过。
  开发HOME不可见；共享宿主内核与基础OS，不计作第二台机器或远端CI。
- MIT自有源码、第三方许可与来源、CI配置、固定依赖、公共接口签名、实测演示脚本和一页赛事说明。
- [GitHub Run42329267843](evidence/github-actions/run-42329267843/README.md)：托管Ubuntu24.04
  的offline及public-corpus均成功。原始ZIP摘要、包内manifest、源提交与日志均重验通过；
  27/27、620612单元格及元数据、最大ULP0。严格绑定源码commit
  0dc4b95e001bc86253926be66321eb0e0f71b4db，原P0没有变化。

运行入口：`python3 tools/check.py`；真实验证：
`.cache/venv/bin/python tools/check.py --oracle --corpus`；
演示：`bash tools/demo.sh [--real]`；构建产物：
`_build/native/release/build/cmd/moonxpt/moonxpt.exe`。
现有过滤版库zip由 `moon package` 生成于 `_build/publish/any07557-moonxpt-0.1.0.zip`。
该旧包保留作历史，阶段B最终库包与含Git历史的完整源码包已生成到dist/0.1.0/stage-b/，
来源提交2cddd31bb8b88648f619969dbb4fe195051735b4；[制品及干净验证证据](evidence/artifacts-20261107/README.md)。

## 已知限制与未验证项

- 唯一实测平台是Linux x86_64 native，其他后端不作支持声明。
- V5本身无行数，默认严格拒绝不可区分的尾部/成员数据；提供精确hints或显式trim策略。
  trim可能丢空白行；合法的伪成员头与多成员必须按公开策略处理。
- Double语义向零截断，低位可能丢失，CSV不承诺文件hash；write_raw可保留原始字段。
  reserved头字段、描述符尾部、间隙与缺少来源时间的头部会规范化。
- ReadStat不用于证明多成员；xport DataFrame不用于证明特殊缺失；R未运行。证据边界逐项公开。
- 输出成组发布支持进程内错误回滚，不承诺两文件跨机器崩溃原子性；遇并发外部更改会保留恢复备份。
- 原工具链403已定位为安装器归档版本键错误并修复，官方固定版本全新安装通过。
  [安装报告](toolchain-installation.md)保留HTTP调查及两次失败。独立云端runner已通过，
  人工指定的第二台SSH主机没有另测；不自动回退latest。
- [GitHub v0.1.0](https://github.com/any07557-wq/-MoonXPT/releases/tag/v0.1.0)已发布，
  annotated tag固定于两类制品源码2cddd31；标签完整CI两类job及7个附件回下载均通过，
  见[阶段C记录](evidence/release-20261107/README.md)。
- Mooncakes尚未发布，后续命名空间已确认any07557-wq；[预备包与迁移边界](mooncakes-preparation.md)
  单列。赛事表单未提交；[十一月实际要求](monthly-contest-202611.md)已复核，正式截止通知仍需关注。

## 实际提交审计

首次本地交付C01—C16共16笔实质性提交，未空提交、倒填日期或squash。
以下审计固定于C16基线；后续发布收尾使用追加提交另计，不改写这16笔历史。
C16完整hash在本次证据归档修订中补齐，不要求任何提交写入其自身hash。

| ID | 阶段 | 实际 hash | 主题 |
|---|---|---|---|
| C01 | S0 | `7aa806ee6cfeae096b8bcc47e1641da028496224` | docs: establish scope, dedup evidence and fixture plan |
| C02 | S1 | `7189a4785f7ea7efe8af1096efd61a401c6f6141` | chore: bootstrap MoonBit package and native build workflow |
| C03 | S1 | `596e59e1ab05ac7a9583e7a74676cfb9250ee3ec` | feat: define XPT data model and diagnostic contracts |
| C04 | S2 | `0b5d52406fe83b8279ee931bbeefd1b7ed89f488` | feat: implement bounded binary record primitives |
| C05 | S2 | `df3dd8707698bb3302b1a8c86e9eff9792b6cdf0` | feat: implement IBM numbers, missing values and text encodings |
| C06 | S2 | `2404cf6361b5ecbd82c1fa4094fab0ffd61325b9` | feat: parse V5 library and variable metadata |
| C07 | S2 | `f93a9b23c70433d2a9aa118c2f4a059ac8aa3ba2` | feat: stream observations across dataset members |
| C08 | S3 | `796fe454a374c450299d4bf9bf01b505e39d903f` | feat: write validated V5 headers and schemas |
| C09 | S3 | `e1bfbf11112cf7e964d5c6c157b059767e4fb291` | feat: stream V5 rows and verify writer interoperability |
| C10 | S4 | `c46d08c359e5c4f67c7d2cd5e00600b20a9ffb32` | feat: add inspect CLI and structured diagnostics |
| C11 | S4 | `fd72a23dea7ee484b495d94bf40c17be1af73c71` | feat: export CSV with versioned XPT metadata |
| C12 | S4 | `c4e1d924f497cf5d069eb36f6a237647626bf7f4` | feat: rebuild XPT from CSV and metadata |
| C13 | S5 | `49990b2cb7907e503815aa498fb8333167f6d446` | test: validate public datasets against independent readers |
| C14 | S5 | `1268113518ae69abc96246e0768d8b06bdef777a` | fix: harden malformed input and streaming boundaries |
| C15 | S6 | `d4d4af23636592c4d4b6d8fb9d8f5ed9cd7135a0` | ci: add reproducible compatibility checks |
| C16 | S6 | `1516dfd033d4ecee1bf0fd5cb35c9ec77762a774` | docs: deliver usage examples and contest handoff |

## 发布状态与后续步骤

1. 独立AI审查原文保留；R1版本、R2最终制品及GitHub正式发布已关闭，见[处理状态](release-review-2026-11-07.md)。
2. 阶段A/B已验收；阶段C按用户明确授权完成push、精确制品标签、两类云端CI和正式Release。
3. Mooncakes仅完成新命名空间的派生预备包与本地检查；完整仓库迁移、最终打包/验收及发布授权仍待处理。
4. 十一月申报表要求参赛者本人撰写申报书；docs/contest.md仅技术事实材料，不能直接提交。
   报名信息、私人材料、参赛方向及官方通知由参赛者确认，未代填表单或入群。

原16笔基线保持冻结，发布收尾追加提交。云端成功与原失败材料分开归档，见
[外部验收说明](external-verification.md)及[历史准备证据](evidence/ci-preparation/README.md)。
历史失败与验收快照保持原样；后续发布文档提交不改变v0.1.0源码身份或附件。
