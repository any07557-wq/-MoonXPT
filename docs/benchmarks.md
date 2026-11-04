# 流式实验（2026-11-04）

后端：MoonBit native release；Linux x86_64。`moon build --target native --release --deny-warn && python3 tools/benchmark.py` 实际运行。工具链/系统和原始数字见 benchmark-results.json。

负载是重复自有 ReadStat 小夹具中的一行，不是生产语料或新增 NHANES 样本。生成器按 4096 行块写磁盘，不参与被测子进程的 RSS。GNU /usr/bin/time 分别测完整 XPT→CSV/JSON 导出与 CSV/JSON→XPT 写入，包含磁盘、临时文件发布与 fsync；行数和文件大小均检查。

| 合成行数 | XPT 字节 | 导出秒 | 导出 RSS KiB | 写入秒 | 写入 RSS KiB |
|---:|---:|---:|---:|---:|---:|
| 10000 | 141040 | 0.04 | 3112 | 0.03 | 3116 |
| 100000 | 1401040 | 0.38 | 2600 | 0.32 | 2832 |
| 1000000 | 14001040 | 3.83 | 2744 | 3.19 | 2852 |

输入从 141040 增至 14001040 字节（行数 100 倍），两条路径的 RSS 都没有随总行数线性积累。本轮峰值约 2.5–3.1 MiB。计时分辨率 0.01 秒，短任务 RSS/启动噪声可明显；不外推其他机器吞吐或宣称优于其他库。

结构依据：Reader 只保存当前 schema、一行附近的尾部缓冲，以及至多一组配置上限内的候选描述符回放；CSV parser 只保存一个限长记录与 4096 字节输入块；Writer 保存 schema 和当前行。JSON 只存 schema 和计数。候选回放最坏约 max_variables×140+头部，行缓冲受 max_row_bytes 约束，均不随总行数增长。

1/7/79/80/81 字节 chunk 一致性、提前停止未读完整文件、短读、源失败、sink 失败和失败后禁止 finish 另由 MoonBit 测试验证。
