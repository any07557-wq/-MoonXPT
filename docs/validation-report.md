# 验证报告（2026-11-04）

所有命令均已实际执行。核心与发布 CLI 不加载 Python、R 或其他统计解析器。S5 的异常/性能补充仍在进行，见进度文件。

## 真实数据全链路

`moon build --target native --deny-warn` 后，`.cache/venv/bin/python tools/validate_corpus.py`：三份文件均完成 inspect → export → write → 独立 pyreadstat 读取，逐列、逐值和缺失掩码比较；CSV 另由 Python csv 解析。原始与重建文件的变量标签、format/informat、宽度、位置、顺序、hash、number、成员名和元数据视图均比较。SHA-256 先按清单验证。结果见 corpus-results.json。

| 数据 | 行 | 列 | 单元格 | 最大实际误差 |
|---|---:|---:|---:|---:|
| DEMO_J | 9254 | 46 | 425684 | 0 ULP |
| BMX_J | 8704 | 21 | 182784 | 0 ULP |
| GLU_J | 3036 | 4 | 12144 | 0 ULP |

允许的一般 Double 语义比较规则为最多 1 ULP（ReadStat 读取会截断低位，本库最近舍入）；整数、缺失、标签、位置和编码精确比较。真实样本此轮实际没有使用容差。IBM 56 位到 IEEE 53 位可能丢低位；write_raw/raw API 可保留字段，CSV 不承诺文件 hash。

## 独立实现及其边界

- pyreadstat 1.3.7 与 ReadStat 是同一家族。read_xport 无 user_missing 参数。它对本库四成员文件返回错误的首成员 145 行，把后续头部当作数据；多成员结果不拿它作证。
- Python xport 3.6.1 是独立实现家族。tools/xport_compat.py 仅修复 pandas 3 移除的 Series fastpath 构造参数和 copy 语义；不修改任何解析或编码算法。它独立读取 MoonXPT 写出的 NUMBERS(3)、WORDS(3)、TAGS(28)、EMPTY(0) 全部成员。ReadStat 另读取首成员单独切片。
- xport DataFrame 会合并 NaN payload，故特殊缺失直接调用其底层 ibm_to_ieee，对每个 tagged value 检查 name 和 bytes，再与规范向量逐字节对照。普通 . 单独检查；不以 NaN==NaN 证明标签保留。
- Python xport writer 拒绝部分原始 HFP 可表示的高指数；reader 丢弃 IBM 低 1–3 位。本库范围/舍入规则以独立规范算式及 Python Fraction 向量为依据，差异公开，不扩大容差迁就。
- R foreign 未安装、未运行，不计通过。非 ASCII 原始字段不使用会 trim 的 oracle 文本输出证明；核心逐字节向量与交换保留测试另行覆盖。

## 已执行的离线检查

- `moon test --target native --deny-warn`：22 个测试组通过，包括 64 个 xport 独立编码常量 × 7 种宽度、128 个 Python Fraction 最近舍入解码常量、全部 28 个缺失、全部有定义 CP1252 字节双向测试。
- `python3 tools/test_inspect.py`：稳定 JSON、未知行数、多成员计数、路径空格、stdout/stderr、2/3 退出码。
- `python3 tools/test_export.py`：选成员、Python csv/json 对照、默认拒绝覆盖、force、同路径和失败清理。
- `python3 tools/test_exchange.py`：四成员分别导出/重建；CSV/JSON 语义一致；缺失与字符 .A 分开；重复列、未知 schema、错误列数和引号失败。
- `python3 tools/test_fixtures.py`：ReadStat 独立输入、xport 独立双成员输入、Windows-1252 €é/标签、DATE/BEST format/informat、136 字节描述符、描述符顺序不同于存储位置。小夹具来源和 hash 见 tests/fixtures/manifest.json。
- `.cache/venv/bin/python tools/check_writer.py`：外部读写和特殊缺失底层适配验证。

## 关键失败与修复留痕

真实输入揭示 MEMBER 的 160 字段偏移错误（65，合成探针曾误为63）；已修复。C10 最终集成检查前已提交，后发现 Int64 ToJson 是字符串；C11 显式 number+十进制 repr 修复并通过回归。未删除失败测试或调整期望掩盖产品缺陷。
