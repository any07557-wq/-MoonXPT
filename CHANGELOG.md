# 更新记录

## 0.1.0（2026-11-07，GitHub Release）

MoonXPT的首个产品版本，[annotated tag及GitHub Release v0.1.0](https://github.com/any07557-wq/-MoonXPT/releases/tag/v0.1.0)
已发布；标签和两个最终制品均绑定2cddd31bb8b88648f619969dbb4fe195051735b4。
模块、CLI和消费方依赖统一使用0.1.0，Mooncakes尚未发布。

- MoonBit原生SAS XPORT V5流式读写库及inspect/export/write CLI。
- 单/多成员、136/140描述符读取、IBM数值、28种缺失、ASCII/Windows-1252及原始字节。
- UTF-8 CSV与schema_version=1的JSON元数据交换，显式尾部策略及结构化诊断。
- 发布准备将CLI帮助横幅从0.1补齐为0.1.0，并将其与模块版本的关系纳入现有CLI检查。

支持范围保持Linux x86_64 native；详细策略与限制见[兼容矩阵](docs/compatibility.md)。
本次版本整理不改变SAS来源版本元数据、交换schema版本、数值舍入或文件格式行为。

正式标签的[Run42361761773](https://github.com/any07557-wq/-MoonXPT/actions/runs/42361761773)
两类CI成功：27/27、620612单元格及元数据、最大ULP0；下载artifact完整性与源码身份重验通过。
发布的7份附件已重新下载并逐份核对大小/摘要，见[发布证据](docs/evidence/release-20261107/README.md)。

制品：`moonxpt-0.1.0.zip`（使用者库包）、`moonxpt-0.1.0-source.zip`（完整评审源码及29次Git历史）。
另附验证证据ZIP、SHA256SUMS和外部清单。两个原始制品保持阶段B字节与模块名any07557/moonxpt；
后续any07557-wq/moonxpt的Mooncakes迁移独立处理，不覆盖本次附件或移动标签。
