# ADR-003：V5尾部与成员链

日期2026-11-11；状态：C01设计审查完成，后续实现按阶段追加结果。
依据为官方TS-140现行28页October2021修订本、SAS官方EOF问答、固定ReadStat源码及
Python xport3.6.1。来源摘要及访问记录见[evidence/v0.2.0/c01/sources.json](evidence/v0.2.0/c01/sources.json)。

## 已核实的规范与工程决策

| 规则 | 规范/参考行为 | MoonXPT决定与测试 |
|---|---|---|
| 80字节物理记录 | TS-140 pp3、6–7，头/描述符/观测补ASCII空格，无特殊结束记录 | S/B均须对齐；P为最小补齐长度0..79；B08–B13、M22–M23 |
| NAMESTR布局 | pp4–6：136/140长度，nlng及npos明确 | validate_layout先检查区间/重叠/上限，W=max(position+width)；间隙允许为原始存储；B17–B18、M12–M14 |
| 行数信息 | pp6–7 OBS未提供V5行数；官方EOF问答说明短全字符空白末行可能丢失 | 不从blank/EOF猜行数；枚举N/P并报告多个候选；B01–B20 |
| N/P公式 | 固定跨度、物理边界及最小空格填充共同推出D=N*W+P；公式本身不证明边界 | 逐一验证对齐、布局、后继结构及限额，W>=80也照检；B05–B07 |
| 下一成员 | pp4–7每成员都有完整头链；数据可以含相同字节 | 只在记录边界验证完整结构，最终以到EOF的合法成员链数决定；M01–M23 |
| 标准padding | TS-140为空格；xport注释仅提及他人报告NUL，未证明其为SAS规范 | StrictSpec仅0x20；NUL兼容须显式选择、带独立fixture/限制说明；B11、A04 |
| 参考reader差异 | ReadStat延迟短全空白尾行并丢弃；>=80空白行保留。xport在全空白观测处终止，字符rstrip且忽略npos | 不把其输出当行数/原始字符/重排布局真值；R08–R10分列限制 |
| Writer风险 | SAS EOF问答明确W<80、全字符、末行全空格的组合；不证明所有全空白宽行都危险 | 默认拒绝该已知组合，提供显式allow；不修改数据；A14–A16 |

## 单成员resolver

独立函数输入已校验schema、OBS起点S、可信边界B、末尾不超过79字节及策略；
计算D=B-S，枚举0<=P<80且P<=D、末P字节全部符合策略、D-P整除W的N。
不需要缓存观测；N使用Int64，乘加前除法/差值检查。W=0只准零观测，是明确工程策略。
hint筛选候选且须验证边界；不足、超出或非标准填充不能被hint隐藏。
0候选是布局/截断/填充失败，1候选inferred/provided，多候选row_count ambiguous。
候选数不超过80，顺序固定。没有额外信息时，无法区分某些“完整行被截掉”和合法短文件；
不得在信息不足时声称恢复作者原始行数。部分物理记录无hint时也不能总能区分损坏发生在
观测或填充，诊断须保留实际offset与阶段，不凭作者意图分类。

## 全局成员链及流式限制

完整结构候选成为有向无环图节点，边携带前成员N/P候选；EOF是终点。搜索同时验证
成员名唯一、逐成员hint、max_members及候选/搜索工作限额；0路径与>=2路径区分。
同一结构路径上的多个N是行数歧义，不误标成成员链歧义。原始数据恰好组成另一合法链
仍报歧义；唯一只针对此契约，不证明作者意图。

普通单成员保留逐行拉取与最多一行+末记录lookahead。发生结构分叉后才做全局前瞻。
可重定位Input可重新读取，扫描只保存有界候选结构和边界尾字节，不保存所有观测。
不可seek输入只有有界分叉回放缓存；超过配置限额返回E_V5_RESOURCE_LIMIT，不能猜边界。
这是单遍不可seek输入需要全局未来信息时的明确资源限制，不能宣称任意长度分叉都常量内存成功。
停止拉取停止I/O；已发出的前缀不代表整个文件验证成功，CLI仍须完整成功才发布stage。

## API兼容与状态

保留ReadOptions、WriteOptions及旧TailPolicy Reject/TrimPadding；新策略通过带默认值的
额外构造参数或新增类型提供，避免破坏既有全字段record构造。RequireExplicitCount为新
行数策略。TrimPadding是保留的显式有损兼容选项，绝不作为StrictAuto的回退。
hint继续--rows MEMBER=COUNT，按大小写归一成员名绑定，未知/重复/负数/溢出拒绝。
保留Diagnostic.kind及旧退出码；新V5代码和边界报告增量暴露。

inspect分别记录row_count_status（not_scanned/inferred/provided/ambiguous/invalid）和
boundary_status（unverified/validated/ambiguous/invalid），候选、padding及对齐独立报告。
Writer保留finish()->Unit调用，并另提供finish_report返回逐成员实际行数/成员数/诊断。
默认已知短全空格末行风险失败，显式allow保留原数据并给出报告；旧调用签名兼容，
此风险默认行为收紧须公开说明。底层Output不能承诺撤销已经交付的流；CLI用stage负责回滚。

## 测试计划与门禁

- B01–B20：零/一行、宽度79/80/81、唯一/多解、最小/最大pad、损坏、hint、溢出/间隙/重排。
- M01–M23：多schema与空成员、伪头、完整多路径、136/140、chunk、资源与对齐。
- A01–A18：报告状态、JSON/stdout/stderr/退出码、逐成员hint、输出回滚、Writer及旧API。
- S01–S14：真实SAS双向；目前blocked，仅准备程序，不能用其他oracle替代。
- R01–R15：ReadStat家族与Python xport双向、语义限制、旧语料、资源/非seek/clean checkout/旧证据hash。

C01检查：现有fixture的W与npos已审计，原27组离线通过；设计没有把工具裁剪行为当规范。
实现不更换既有数值容差，不移除旧测试，不改旧报告。后续发现假设错误先追加修订本ADR。
