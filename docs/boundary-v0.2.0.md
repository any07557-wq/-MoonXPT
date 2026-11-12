# v0.2.0开发边界契约与迁移

开发目标0.2.0，尚未发布。v0.1.0标签与证据保持不变。依据及兼容例外见
[ADR-003](adr-003-v5-boundary-resolution.md)，真实SAS验证目前blocked。

## Reader与资源

旧ReadOptions全字段构造、row_hints和TailPolicy Reject/TrimPadding保留。新参数：

```moonbit
let reader = @xpt.Reader::new(input,
  options={ ..@xpt.ReadOptions::default(), row_hints: { "DEMO": 9254L } },
  boundary_options={ ..@xpt.BoundaryOptions::default(),
    row_count_policy: @xpt.RequireExplicitCount,
    padding_policy: @xpt.StrictSpec,
    max_boundary_candidates: 64,
  })
```

StrictAuto仅在合法行数/完整成员链唯一时接受；RequireExplicitCount逐成员要求hint。
重复大小写名称、未知/负数/溢出hint均拒绝；hint仍检验行长、最小padding、对齐及下一完整头/EOF。
成员限额沿用limits.max_datasets，CLI为--max-members；其他默认限额为64次候选头探测、
16MiB回放/累计头结构预算、16384次图搜索工作。候选结构（包括失败探测）缓存并限额。

普通读取逐行拉取。结构分叉需要全局前瞻：Input::new可选reposition回调，平台普通文件和
input_from_bytes提供它，不保存整个观测区。不可seek来源仅缓存有限分叉后缀，超限报
E_V5_RESOURCE_LIMIT；不保证任意长度的非seek分叉可成功。提前停止不继续I/O，调用方负责关闭。
发现歧义/损坏后Reader失效，不能通过再次调用跳过错误。

StrictSpec只接受ASCII空格。CompatibilityNulPadding仅是显式非标准兼容选项，接受空格/NUL，
不将NUL宣称为SAS规范；合成变异fixture、来源和hash在tests/boundary/fixtures/manifest.json。
独立工具的实际结果另归interop证据，不能用接受NUL推论它能验证padding合法性。

## CLI与JSON

保留重复--rows MEMBER=COUNT；没有新增不稳定的数组索引hint。示例：

```sh
moonxpt inspect input.xpt --json --count-rows
moonxpt inspect input.xpt --json --header-only
moonxpt export input.xpt --member DEMO --rows DEMO=9254 --require-row-count \
  --csv output.csv --metadata output.json
```

inspect默认仍遍历数据以发现后续成员；--count-rows控制是否输出计数，状态反映实际扫描结果。
--header-only只识别第一个schema，scan_complete=false，row_count_status=not_scanned且
boundary_status=unverified，不代表文件完整验证。扫描后分别报告inferred/provided/ambiguous/
invalid以及validated/ambiguous/invalid；两种歧义不会合并。boundary字段含候选、padding、
对齐、OBS/边界偏移、hint、expected/actual bytes及策略。boundary_schema_version=1独立于
CSV交换schema_version=1，不改变旧交换格式。

错误仍为空stdout、JSON stderr和退出码2（I/O为3，内部错误4），保留旧kind/reason字段，
新增code及boundary上下文。例如行数多解可以同时为row_count_status=ambiguous与
boundary_status=validated。结构有效不保证每个数值编码均可解码，export仍逐值验证。

显式--tail-policy trim保留v0.1.0有损语义：选择最早完整合法路径与最大合法padding，可能丢行
或误认数据中的合法头；输出会保留ambiguous状态。严格模式不会自动切换到该策略。

## Writer与输出失败

Writer::new新增tail_policy，默认RejectAmbiguousTail：遇到已知的W<80、全字符且末观测全空格
组合，在end_dataset/finish前拒绝，代码E_V5_WRITER_AMBIGUOUS_TAIL。空成员和W>=80的全空格
观测不因这条风险规则被拒绝。默认行为收紧是v0.2.0的迁移变化，旧方法签名仍可编译。

明确需要该数据时使用AllowAmbiguousTail或CLI --allow-ambiguous-tail，数据字节不改写，
finish_report返回实际成员/行数、padding及逐成员诊断；CLI输出结果并在stderr给warning。
旧finish()->Unit保留。库的外部Output已交付字节不能撤销；CLI始终使用临时stage，成功后
发布，失败清理，保留旧版并发冲突与成组回滚约定。


## C06复现与证据入口（2026-11-12追加）

完整仓库使用tools/check_v020.py的offline/interop/corpus三种模式，分别归档原检查与新增
CLI/资源测试、独立双向夹具、固定真实语料。所有证据路径必须新建，失败保留原日志。
可用tools/reproduce_v020.py对已提交HEAD做新克隆与无项目缓存构建；复用固定SDK这一
边界会写入回执，不冒称新机器/SDK安装。SAS保持blocked，真实执行需后续合法环境。
详情在完整仓库docs/validation-report-v0.2.0.md；库包不携带开发工具或全部证据。
