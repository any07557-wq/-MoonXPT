# GitHub Actions Run 42329267843

归档日期：2026-11-07。[实际运行](https://github.com/any07557-wq/-MoonXPT/actions/runs/42329267843)，
run_number=5，attempt=1，workflow_dispatch，整体success。
开始2026-11-07 10:26:33、更新至10:27:21（UTC+8）；原始API时间保留UTC。
被测源码：`0dc4b95e001bc86253926be66321eb0e0f71b4db`，tree
`b37f1c4f91896ab370b9ee880eee25be774a8386`。P0与C16冻结基线比较无差异。

| job | 结果 | artifact ID | 已核对内容 |
|---|---|---|---|
| [offline](https://github.com/any07557-wq/-MoonXPT/actions/runs/42329267843/job/128271781674) | success | 13556537196 | 新SDK、格式/检查/构建、27/27测试、6项离线集成；不安装oracle/语料 |
| [public-corpus](https://github.com/any07557-wq/-MoonXPT/actions/runs/42329267843/job/128271781196) | success | 13556427438 | 新SDK、新venv/oracle、重新下载语料，27/27及完整独立对照，全部请求项执行 |

云端为GitHub托管Ubuntu 24.04 Linux x86_64，内核7.0.0-1017-azure，Python3.14.4，
与本机WSL/Ubuntu26.04环境不同。SDK固定moon0.1.20261012/748b63c、moonc
v0.10.15+943464bfa；两个job均重新下载SDK，完整job无pip/语料缓存复用。
这形成独立云端runner证据；没有另行执行人工配置的第二台SSH主机测试。

## 完整兼容性结果

| 语料 | 行×列 | 对照单元格 | 最大ULP | 元数据 |
|---|---|---|---|---|
| DEMO_J | 9254×46 | 425684 | 0 | 声明属性精确一致 |
| BMX_J | 8704×21 | 182784 | 0 | 声明属性精确一致 |
| GLU_J | 3036×4 | 12144 | 0 | 声明属性精确一致 |
| 合计 | | 620612 | 0 | |

ReadStat与Python xport仍按各自边界使用；四成员与全部28缺失标记的独立检查通过。
完整日志含79截断、256变异、8定向错误与公共消费方通过，最终明确none skipped。

## 原始材料与完整性

- run.json、jobs.json、artifacts.json：gh api GET响应原样保存，含run/job/artifact完整身份。
- 两个原始artifact ZIP及artifacts/下解压内容：原ZIP大小与GitHub API一致，SHA-256与
  GitHub的digest字段逐个匹配；13+19份包内manifest记录均核验，解压内容与ZIP逐字节一致。
- workflow-logs.zip与workflow-logs/：完整工作流日志，ZIP摘要为下载后观察值，
  没有把它声明为GitHub发布的独立校验值。日志中的警告、时间、路径与空行均保留。
- retrieval.json、downloads.json记录只读来源和取得时间；未保存鉴权token或签名重定向URL。
- workflow.yml是被测commit的配置快照；verification.json是本地重验生成的派生摘要。
- manifest.json登记此目录全部归档文件的字节数与SHA-256，不包含自身。

| 原ZIP | GitHub SHA-256 |
|---|---|
| offline-42329267843-1.zip | daf0f5f0b5942ae7d7b1aca3bbc687c95376c8a2c4bda891f62438fece48dd1e |
| public-corpus-42329267843-1.zip | 4d110a02414a4839b1c88a31ff9aabe0d0098d17ff5dd75b0eea2fa29d59c7bd |

从仓库根目录可离线重验（需要本地Git含被测commit）：

```sh
python3 tools/verify_ci_evidence.py docs/evidence/github-actions/run-42329267843
```

验证器检查GitHub ZIP摘要、ZIP与解压文件、两层manifest、job/source上下文、安装器及
输入快照、SDK摘要与版本、依赖版本、测试步骤和真实语料结果；同时重算被测commit的
Git archive摘要。它只读取文件与Git对象，不触发工作流，也不重新运行产品测试。

本地11-06的两次下载超时与11-05的两次安装失败继续保留，未被本次成功记录覆盖。
此次CI只证明上述被测commit的技术验收；正式版本标签、Release制品、Mooncakes和赛事
提交仍需分别完成。后续归档/审查提交不能冒称是该run的被测HEAD。
