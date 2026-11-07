# 更新记录

## 0.1.0（待发布）

MoonXPT的首个产品版本，目标标签为v0.1.0；此文档是发布说明草稿，不表示已创建Tag、
GitHub Release或Mooncakes版本。模块、CLI和消费方依赖统一使用0.1.0。

- MoonBit原生SAS XPORT V5流式读写库及inspect/export/write CLI。
- 单/多成员、136/140描述符读取、IBM数值、28种缺失、ASCII/Windows-1252及原始字节。
- UTF-8 CSV与schema_version=1的JSON元数据交换，显式尾部策略及结构化诊断。
- 发布准备将CLI帮助横幅从0.1补齐为0.1.0，并将其与模块版本的关系纳入现有CLI检查。

支持范围保持Linux x86_64 native；详细策略与限制见[兼容矩阵](docs/compatibility.md)。
本次版本整理不改变SAS来源版本元数据、交换schema版本、数值舍入或文件格式行为。

既有[云端验收](docs/evidence/github-actions/run-42329267843/README.md)绑定提交
0dc4b95e001bc86253926be66321eb0e0f71b4db：两类CI、27/27及620612单元格对照通过。
它没有验证后续的版本横幅改动。当前版本整理的本地检查另行登记，最终候选制品和发布
状态见[版本说明](docs/versioning.md)与[发布审查](docs/release-review-2026-11-07.md)。

计划制品：`moonxpt-0.1.0.zip`（使用者库包）、`moonxpt-0.1.0-source.zip`（完整评审源码）。
两者产品版本均为0.1.0，内容与清单按用途分别核对；完整发布制品验收及授权另行完成。
