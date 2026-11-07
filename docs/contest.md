# MoonXPT 一页赛事说明

2026-11-07更新；技术事实材料，尚未提交赛事表单。
实际报名表要求申报书由参赛者本人撰写，禁止AI代写；本文是开发模型生成的技术记录，
不能直接作为申报书提交。[十一月规则与表单复核](monthly-contest-202611.md)另列所需内容。

**用户与问题。** 需要在 MoonBit 程序中读取 NHANES 等 SAS XPORT 公开统计数据、
保留缺失/标签/格式并交换表格的开发者。普通 CSV 转换会丢列类型、缺失标签和
SAS 元数据；只读首成员的解析工具也不能完整处理多成员库。

**交付。** MoonBit 为主要语言的 V5 流式库和 native CLI：inspect 查看 schema、
export 选成员导出 CSV/JSON、write 按声明 schema 重建 XPT。支持136/140字节
描述符、非顺序字段、28种缺失、IBM数值、原始字符、ASCII/Windows-1252和多成员。
P0逐项证据见兼容矩阵，不用 stub 或内部 round-trip 冒充外部互操作。

**演示。** `bash tools/demo.sh --real` 用 DEMO_J 9254×46 完成检查/导出/重建；
`tools/validate_corpus.py` 对 DEMO_J、BMX_J、GLU_J 共620612个单元格逐值与独立工具
比较，实际差异0 ULP。第二实现 Python xport 读取所有输出成员；特殊缺失另用
低层适配及独立向量验证。默认检查无需下载语料或安装 oracle。

**稳健性与边界。** V5 无行数，严格策略诊断不可消除歧义，显式提示可保留空白行。
原始字段和数值语义分开，CSV不承诺文件hash。79个截断、256个变异及百万行合成
流式实验均记录。只承诺已验证的 Linux native；V8等扩展不在本期。

**连续贡献与开源。** 本任务新建仓库，无开始基线hash；按阶段产生16次实质性
本地提交（最后C16主题为 docs: deliver usage examples and contest handoff），
实际明细见 handoff.md / Git。MIT源码，规范与验证来源见第三方说明。
后续收尾使用追加提交，公开仓库为https://github.com/any07557-wq/-MoonXPT。
[正式标签CI](evidence/github-actions/run-42361761773/README.md)的两类job均通过，
原ZIP、日志和摘要可离线重验；[v0.1.0](https://github.com/any07557-wq/-MoonXPT/releases/tag/v0.1.0)
已发布，源码制品包含截至2cddd31的29次历史提交。

**赛事状态。** 11-04/05仅取得十月或JS入口信息；11-07已从官方当前源码及十一月表单
重新核实，未覆盖早期观察。[实际要求](monthly-contest-202611.md)包括最多3人、有效提交、
公开可复现、本人申报书及入群要求。表单当前配置至北京时间11-30 23:59:59，官网仍以
官方通知为准，不能将配置窗口直接当作正式验收截止公告。私人资料与本人申报书由参赛者
通过官方表单处理；本轮未发布Mooncakes、代填赛事表单、入群或联系他人。
