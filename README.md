# MoonXPT

当前开发目标：**0.2.0（尚未发布）**，本轮增强V5尾部与成员边界。
API、CLI及迁移变化见[新边界契约](docs/boundary-v0.2.0.md)。
已发布稳定版仍为[GitHub Release v0.1.0](https://github.com/any07557-wq/-MoonXPT/releases/tag/v0.1.0)，
其标签和原始制品保持不变；下述云端验收记录属于v0.1.0。

用 MoonBit 逐行读写 **SAS XPORT V5**，查看 NHANES 等公开统计文件，并通过
CSV + 版本化 JSON 元数据在程序间交换数据。核心解析、IBM 浮点、缺失标记、
字符编码和 CSV/JSON 都由 MoonBit 实现；C 仅适配文件系统。
产品库和 CLI 运行不依赖 Python、R 或外部统计解析器。

已验证 Linux x86_64 native。本地与GitHub托管Ubuntu 24.04均通过技术验收，
[公开仓库](https://github.com/any07557-wq/-MoonXPT)已保留连续历史；Mooncakes尚未发布。
正式标签的[完整CI与发布核验](docs/evidence/release-20261107/README.md)已归档。
完整边界见[兼容矩阵](docs/compatibility.md)，
证据见[验证报告](docs/validation-report.md)和[交接报告](docs/handoff.md)。
独立审查处理状态见[发布审查](docs/release-review-2026-11-07.md)。

完整评审源码包与库包分别提供。本文面向完整源码；库包入口为[库使用说明](README.library.md)，
模块readme字段指向该文件。制品内容与历史恢复方法见[打包说明](docs/artifacts.md)。
标签及两个制品固定于 `2cddd31bb8b88648f619969dbb4fe195051735b4`；后续发布证据另行追加。
已发布制品保留模块名 `any07557/moonxpt`；后续Mooncakes改用 `any07557-wq/moonxpt`，
迁移准备与未完成项见[Mooncakes说明](docs/mooncakes-preparation.md)。

## 构建与使用

工具链为 `moon 0.1.20261012 (748b63c)` / `moonc v0.10.15+943464bfa`，需要 C
编译器。固定版本全新安装已在同机隔离用户空间验证；安装步骤和 CI 状态见
[复现说明](docs/reproduction.md)。

```sh
moon build --target native --release --deny-warn
xpt_cli=./_build/native/release/build/cmd/moonxpt/moonxpt.exe
"$xpt_cli" --help
mkdir -p .cache
xpt_demo_dir="$(mktemp -d .cache/demo-XXXXXX)"

"$xpt_cli" inspect tests/fixtures/readstat-v5.xpt --json --count-rows --rows ORACLE=4
"$xpt_cli" export tests/fixtures/readstat-v5.xpt --member ORACLE --rows ORACLE=4 \
  --csv "$xpt_demo_dir/data.csv" --metadata "$xpt_demo_dir/data.meta.json"
"$xpt_cli" write "$xpt_demo_dir/data.csv" --metadata "$xpt_demo_dir/data.meta.json" \
  --output "$xpt_demo_dir/restored.xpt"
```

这些步骤也可执行 `bash tools/demo.sh`。真实数据演示：

```sh
python3 tools/fetch_corpus.py
bash tools/demo.sh --real
```

真实清单包含 DEMO_J（9254×46）、BMX_J（8704×21）、GLU_J（3036×4），下载前后
校验固定 SHA-256。[来源清单](tests/corpus.json)不包含原始调查数据。
Source: CDC/NCHS；原始资料可在 CDC 网站免费取得，引用与本项目不代表 CDC、HHS
或美国政府背书。请遵守[数据用户协议](https://www.cdc.gov/nchs/policy/data-user-agreement.html)，
仅用于统计报告和分析，不尝试识别个人或链接可识别信息。

## 公共 API

包名 `any07557/moonxpt`；交换层为 `/exchange`，native 文件适配为 `/platform`。
通过 `moon.work` 同时列出本库和消费方模块即可本地依赖，具体声明见
[复现说明](docs/reproduction.md)。[独立消费方检查](tools/test_consumer.py)已实际编译。

```moonbit
let reader = @xpt.Reader::new(input, options={
  ..@xpt.ReadOptions::default(),
  row_hints: { "ORACLE": 4L },
})
while reader.next_dataset() is Some(schema) {
  while reader.next_row() is Some(row) {
    // row.raw 是完整观察字节；row.values 按变量顺序提供值。
    // Numeric(Finite(n))、Numeric(Missing(tag))、Character(bytes)。
    println("\{@xpt.text_field(schema.name, @xpt.Ascii)} row \{row.index}")
  }
}
```

`Input::new((requested) => chunk)` 允许短读；空字节表示最终 EOF。
停止拉取立即停止 I/O，调用方关闭其输入。`Output::new` 的回调完整写入或抛错。
`Writer::begin_dataset → write_row / write_raw → end_dataset / finish` 支持多个成员，
固定时间戳可注入；失败后禁止继续写入或 finish。
完整可运行示例：[逐行扫描](examples/scan/main.mbt)、[四成员写入](examples/write/main.mbt)。
导出接口见[核心签名](pkg.generated.mbti)、[交换层](exchange/pkg.generated.mbti)。

普通缺失 `.`、`._`、`.A`—`.Z` 均有独立 Byte 标记；字符 `.A` 是字符串。
字符字段保留全部存储字节及尾部空格，文本视图显式选择 ASCII/Windows-1252。
变量标签、format/informat、存储宽度和位置保留；日期保持原始数值和格式属性。
错误包含 kind、可用的字节 offset、member、row、variable 和 reason；未知上下文为 null。

## 交换与兼容策略

- V5 没有行数。默认严格策略拒绝有多种行数解释的空白尾部，以及成员头与行数据的
  双重解释。重复的 `--rows NAME=COUNT` 给出精确提示，其中NAME大小写不敏感；
  `export --member NAME` 按成员原名精确匹配，使用inspect显示的大小写。
  `--tail-policy trim` 显式选择最大合法填充和结构验证后的成员边界，可能丢弃歧义空白行。
- 数值宽度 2–8 字节；IBM→Double 按 SAS/ReadStat 向零截断，误差小于 1 ULP；
  短宽度写入按规范截断。原始字节可访问，CSV 数值语义往返不承诺文件 hash。
  非有限数、非规范数值、未知编码和超长字段明确报错。
- CSV 为 UTF-8，无 BOM；保留字符空格，支持引号、逗号和字段内 CR/LF。
  JSON `schema_version=1` 决定类型，数值空字段默认报错；可用
  `--numeric-empty-missing` 显式当作普通缺失。详见[交换契约](docs/exchange-format.md)。
- `inspect --json` 输出机器结果；`--count-rows` 才在结果中提供计数。
  输出结果写 stdout，诊断 JSON 写 stderr；退出码 0 成功、2 参数/格式、3 I/O、4 内部错误。
- 默认不覆盖，`--force` 使用同目录独占临时文件和恢复备份；成组发布遇普通错误回滚。
  CSV/JSON 跨文件的机器崩溃原子性不保证。路径别名、覆盖和冲突回滚均有测试。

本期不支持 V8、SAS7BDAT、CPORT、格式执行器或外部值标签目录，不自动猜测编码或日期。

## 验证

```sh
python3 tools/check.py                         # 离线：原27组及新增边界测试、CLI、夹具、异常、公共消费方
bash tools/setup_oracles.sh                    # 仅开发验证需要
.cache/venv/bin/python tools/check.py --oracle --corpus
.cache/venv/bin/python tools/reproduce_clean.py --corpus
```

三份真实文件共 620,612 个单元格及已声明元数据完整对照通过，实际差异 0 ULP。
另有独立多成员生成/读取、全部 28 种缺失、136 字节描述符、字段重排、CP1252、
79 个截断和 256 个固定种子变异。百万行合成导出/写入约 2.5–3.1 MiB 峰值 RSS，
方法与原始数据见[实验报告](docs/benchmarks.md)。

许可证：[MIT](LICENSE)。规范、验证依赖与运行时来源见
[第三方说明](THIRD_PARTY.md)和[参考资料](docs/references.md)。
