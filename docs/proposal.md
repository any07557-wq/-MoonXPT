# MoonXPT 选题说明

2026-11-04。项目路径 `/home/user/MoonBit_Program/MoonXPT`；基线：新建空目录，无已有 HEAD、用户代码或适用 AGENTS.md。Git 已在当前目录初始化，未纳入父目录。

用户：需要在 MoonBit 中读取 NHANES 和交换 SAS transport 数据的开发者。真实任务：检查 DEMO_J、BMX_J、GLU_J 的列和标签，逐行转换为 CSV + 版本化元数据，再重建 V5。

本次交付以用户任务书 docs/task-spec.md 为准：V5 多成员读写、IBM 数值、28 种缺失、原始字节与 ASCII/Windows-1252、严格流式接口和三个 CLI 工作流。V8 与统计分析不在范围内。查重暂未发现直接冲突，详见 dedup.md。

核心算法独立按 SAS 规范实现；ReadStat/pyreadstat 及 Python xport 仅用于开发验证，不作为运行依赖，不复制 GPL 源码。至少三份真实数据逐值对照，特殊缺失和不暴露的属性另用规范向量/适配器验证。

主要风险：V5 无行数，空白尾行与填充可能不可区分；多成员边界须结构验证。默认歧义报错，提供行数提示或显式兼容策略。IBM 56 位有效数到 Double 的语义转换不能承诺文件级字节复刻。native I/O 采用薄 C 适配，格式及交换逻辑均为 MoonBit。
