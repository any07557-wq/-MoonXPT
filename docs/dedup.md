# 查重记录

访问日期：2026-11-04。机器证据：dedup-evidence.json；查询脚本 tools/research.py；只代表本次可访问索引快照。

GitHub 仓库搜索 API，五组词 `xpt`、`xport`、`"sas transport"`、`readstat`、`"statistical data"` + `language:MoonBit` 均成功返回 total_count=0、incomplete_results=false。例：[xport 查询](https://api.github.com/search/repositories?q=xport+language%3AMoonBit)。另用公开网页搜索检查 GitHub README/描述，未发现直接 XPORT 实现；这不能替代未授权的全站代码搜索。

[Mooncakes 原生搜索](https://mooncakes.io/api/v0/search?kw=xport&limit=20) 已实际请求五组词（每次最多 20 个模块）。xport、sas transport 返回空；xpt 命中 graphviz 的 pad_x_pt；readstat 命中 Raft ReadState、Web readyState 等子串；statistical data 命中统计分析、日志聚合等。逐项名称、说明、相关包摘要见 JSON。命中项没有提供 SAS 二进制 transport 到表格语义的读取/写入工作流。

功能对照：MoonReader 提供 CSV/JSON 等文档输入，不含 SAS XPORT；Mooncakes 的统计/聚合包处理已解码数据，没有 V5/IBM/特殊缺失兼容层。跨语言 ReadStat、Python xport 有相关能力，但并非 MoonBit 库，作为独立验证来源。结论：本次证据未发现直接同质项目，继续实现；不宣称唯一性。

[赛事官网](https://moonbitlang.github.io/Hackathon2026/)可访问，但当前静态入口由 JS 渲染；公开索引仍显示十月赛季、10 月 31 日。未取得可靠十一月要求，交付材料不得推定十一月截止日期。
