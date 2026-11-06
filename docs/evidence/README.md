# C15 / C16 验收证据归档

归档日期：2026-11-05。冻结基线是
`1516dfd033d4ecee1bf0fd5cb35c9ec77762a774`；本目录在后续发布收尾提交中归档，
不改变该基线或原有16次提交。

| 验收对象 | 记录 | 来源与状态 |
|---|---|---|
| C15 `d4d4af23636592c4d4b6d8fb9d8f5ed9cd7135a0` | [原始摘要](c15/clean-reproduction.json) | 与C16树中原有docs/clean-reproduction.json逐字节一致；原始完整stdout未在缓存中保留下来，不补造 |
| C16 `1516dfd033d4ecee1bf0fd5cb35c9ec77762a774` | [原始摘要](c16/clean-reproduction.json)、[完整执行记录](c16/final-clean.log) | 从本地缓存原样归档；日志末尾JSON与摘要完全一致，commit完整hash核对通过 |

每份文件的字节数、来源和SHA-256见[清单](manifest.json)。归档没有重新运行测试，
没有更改已有结果、时间数字、警告或路径。

两次记录证明：无构建缓存的Git archive可以重新构建并通过对应检查。
C16包含27组MoonBit测试、6项离线集成、两个oracle家族和3份真实文件全链路。
它们均复用此前安装的工具链与oracle解释器中的依赖，`network_install_verified=false`；
不计为另一台干净机器从零安装通过。

发布收尾新增材料分别归档，不覆盖这两次历史记录：

- [官方工具链来源调查](toolchain-discovery/README.md)：原错误版本键、正确固定入口、HTTP状态和摘要。
- [全新安装验收](independent-install/README.md)：同机隔离用户空间、全新SDK/oracle/语料，完整通过；两次前置失败另存。

上述两个目录各有自己的SHA-256清单，原manifest.json继续只登记C15/C16历史材料。
