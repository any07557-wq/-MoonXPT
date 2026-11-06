# 验证报告（2026-11-04）

所有命令均已实际执行。核心与发布 CLI 不加载 Python、R 或其他统计解析器。S5 异常与性能证据已补齐。

## 真实数据全链路

`moon build --target native --deny-warn` 后，`.cache/venv/bin/python tools/validate_corpus.py`：三份文件均完成 inspect → export → write → 独立 pyreadstat 读取，逐列、逐值和缺失掩码比较；CSV 另由 Python csv 解析。原始与重建文件的变量标签、format/informat、宽度、位置、顺序、hash、number、成员名和元数据视图均比较。SHA-256 先按清单验证。结果见 corpus-results.json。

| 数据 | 行 | 列 | 单元格 | 最大实际误差 |
|---|---:|---:|---:|---:|
| DEMO_J | 9254 | 46 | 425684 | 0 ULP |
| BMX_J | 8704 | 21 | 182784 | 0 ULP |
| GLU_J | 3036 | 4 | 12144 | 0 ULP |

允许的一般 Double 语义比较规则为最多 1 ULP（SAS/ReadStat 与本库均向零截断低位，原始 HFP 语义损失小于1 ULP）；整数、缺失、标签、位置和编码精确比较。真实样本此轮实际没有使用容差。IBM 56 位到 IEEE 53 位可能丢低位；write_raw/raw API 可保留字段，CSV 不承诺文件 hash。

## 独立实现及其边界

- pyreadstat 1.3.7 与 ReadStat 是同一家族。read_xport 无 user_missing 参数。它对本库四成员文件返回错误的首成员 145 行，把后续头部当作数据；多成员结果不拿它作证。
- Python xport 3.6.1 是独立实现家族。tools/xport_compat.py 仅修复 pandas 3 移除的 Series fastpath 构造参数和 copy 语义；不修改任何解析或编码算法。它独立读取 MoonXPT 写出的 NUMBERS(3)、WORDS(3)、TAGS(28)、EMPTY(0) 全部成员。ReadStat 另读取首成员单独切片。
- xport DataFrame 会合并 NaN payload，故特殊缺失直接调用其底层 ibm_to_ieee，对每个 tagged value 检查 name 和 bytes，再与规范向量逐字节对照。普通 . 单独检查；不以 NaN==NaN 证明标签保留。
- Python xport writer 拒绝部分原始 HFP 可表示的高指数；reader 丢弃 IBM 低 1–3 位。本库范围/舍入规则以独立规范算式及 Python Fraction 向量为依据，差异公开，不扩大容差迁就。
- R foreign 未安装、未运行，不计通过。非 ASCII 原始字段不使用会 trim 的 oracle 文本输出证明；核心逐字节向量与交换保留测试另行覆盖。

## 已执行的离线检查

- `moon test --target native --deny-warn`：27 个测试组通过，包括 64 个 xport 独立编码常量 × 7 种宽度、128 个 Python Fraction 向零截断解码常量（独立精确有理数比较决定方向）、全部 28 个缺失、全部有定义 CP1252 字节双向测试。
- `python3 tools/test_inspect.py`：稳定 JSON、未知行数、多成员计数、路径空格、stdout/stderr、2/3 退出码。
- `python3 tools/test_export.py`：选成员、Python csv/json 对照、默认拒绝覆盖、force、同路径和失败清理。
- `python3 tools/test_exchange.py`：四成员分别导出/重建；CSV/JSON 语义一致；缺失与字符 .A 分开；重复列、未知 schema、错误列数和引号失败。
- `python3 tools/test_fixtures.py`：ReadStat 独立输入、xport 独立双成员输入、Windows-1252 €é/标签、DATE/BEST format/informat、136 字节描述符、描述符顺序不同于存储位置。小夹具来源和 hash 见 tests/fixtures/manifest.json。
- `.cache/venv/bin/python tools/check_writer.py`：外部读写和特殊缺失底层适配验证。

## 关键失败与修复留痕

真实输入揭示 MEMBER 的 160 字段偏移错误（65，合成探针曾误为63）；已修复。C10 最终集成检查前已提交，后发现 Int64 ToJson 是字符串；C11 显式 number+十进制 repr 修复并通过回归。未删除失败测试或调整期望掩盖产品缺陷。

## 异常、资源与失败原子性

`python3 tools/test_malformed.py`：seed 20261104，79 个截断位置、256 个1–4字节变异、8个定向结构错误；每次子进程5秒上限，均无崩溃、内部错误或超时。定向数值零指数错误准确关联 offset=1040、member=ORACLE、row=0、variable=VALUE。超大偏移/声明在行分配前失败。

额外 MoonBit 回归：短全空白末行用 hints 保留；80字节全空白行为数据；不完整伪 MEMBER 作为数据回放；完整 polyglot 头默认报歧义。输入恰好等于上限允许 EOF，多出字节被拒绝且回放不吞字节；CSV 非零小数 underflow 不变零；未知行数提示成员拒绝；诊断 nullable context 为 string/null，修复了 core Option ToJson 的数组表示。

platform/stage_wbtest.mbt 实际制造第二目标的竞争文件，验证第一个输出撤回且外部竞争文件不被删除；force 模式旧文件备份确实恢复。跨机器崩溃或回滚时第三方并发改动不承诺全文件事务，遇到恢复失败保留备份并明确报恢复路径。

`tools/benchmark.py` 已测 export 和 write：合成1万/10万/100万行，无线性数据积累；数字、方法和边界见 benchmarks.md / benchmark-results.json。内存证据为 native release Linux，未外推平台。

## 干净检出复现（2026-11-05）

`.cache/venv/bin/python tools/reproduce_clean.py --corpus` 对 C15 d4d4af2 的 Git archive
执行完整检查，11.455秒，PASS；结果见 clean-reproduction.json。
没有复制 _build、虚拟环境或开发目录改动。固定已安装工具链和调用解释器中的
固定 oracle 依赖被明确复用，三份输入复制后重验 hash。27组测试、6条离线集成入口、
独立消费方和所有真实数据链路均通过。

`bash tools/demo.sh` 与 `bash tools/demo.sh --real` 已实际成功；后者在本地演示目录
得到9254行 DEMO_J CSV、metadata JSON和可重新inspect的XPT。代码分发包的清单已检查，
不包含缓存、凭据、oracle程序或真实语料。CI YAML已解析，shell脚本语法检查通过；
GitHub Actions未远端执行；当时的固定归档403没有被计作通过，后续安装修复见下节。

本地源码包检查：`moon package --list` 生成zip后，解压到独立临时目录，
在无tools目录、无缓存/虚拟环境/真实语料的包内容下，`moon build --target native --deny-warn`
和原生CLI inspect独立小夹具成功。目录清单含80项，缓存和凭据路径均不在包内。
repository字段保留空值并出现打包警告，因为尚未创建真实远程地址；未用虚构URL消除警告。

## 发布收尾：全新工具链与依赖（运行于2026-11-05，归档于2026-11-06）

冻结C16 `1516dfd033d4ecee1bf0fd5cb35c9ec77762a774` 的源码由Git archive提取。
同机bubblewrap隔离隐藏开发HOME，先检查SDK与四个oracle模块均不可见，再从官方HTTPS
安装固定SDK/core、从PyPI向全新venv无缓存安装固定oracle，重新下载并校验三份语料。
`tools/check.py --oracle --corpus` 全部通过且无跳过：27组、6项离线集成、两个oracle家族、
三份文件620,612单元格及元数据，实际最大ULP为0。

完整[验收结果、日志和安装器快照](evidence/independent-install/README.md)与原C15/C16
复用环境的记录分别保存。首次DNS挂载失败和第二次缺少可执行位失败同样保留；通过的
第三次运行没有复用失败运行的SDK。共享宿主内核、基础OS、DNS与代理，未验证第二台
机器或新OS镜像，未执行远端CI。原403原因和官方摘要来源见[安装报告](toolchain-installation.md)。

## CI外部验收准备（2026-11-06）

准备提交958f9fce15feeea0ee39f541faafad831af3db38接入同一offline/full验证入口，固定工具链
归档版本键、Python及Actions，保存逐阶段回执。actionlint和本地失败处理检查通过；两类本地
预演均因官方SDK下载超过600秒而FAIL，未进入新的构建与测试，不将旧的27/27对照替代它们。
原始材料见[CI准备证据](evidence/ci-preparation/README.md)。第二台机器及GitHub仓库尚未配置，
没有外部实际运行记录，验收保持未完成。原C15/C16及2026-11-05安装证据不修改。
