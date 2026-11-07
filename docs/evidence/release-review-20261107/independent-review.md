**独立 AI 发布审查，2026-11-07**

审查对象：`9a45c6ea28cfbfba1d6c9508b2d2b634ef04a8f0`。结论是：**现有技术验收证据成立；当前不建议创建正式 v0.1.0 Release。** 尚需关闭版本标识、最终制品及包发布身份方面的缺口。它们主要是发布准备项，不是已经发现的核心解析器缺陷。

本次只读检查了 Git 对象、源码、文档、现有包及归档，并独立执行归档验证器、读取 GitHub API。没有修改文件、重跑产品全套测试、下载工具链或执行远端写操作。

**技术验收证据**

`python3 tools/verify_ci_evidence.py docs/evidence/github-actions/run-42329267843` 返回 PASS。另行通过 GitHub API 核对了 run、两个 job 和两个 artifact，其身份、结论、大小及摘要均与归档一致：

- Run `42329267843`，attempt 1，`workflow_dispatch`，两个 job 均 success；被测提交是 `0dc4b95e001bc86253926be66321eb0e0f71b4db`。
- offline ZIP：12,753 字节，SHA-256 `daf0f5f0b5942ae7d7b1aca3bbc687c95376c8a2c4bda891f62438fece48dd1e`。
- public-corpus ZIP：15,850 字节，SHA-256 `4d110a02414a4839b1c88a31ff9aabe0d0098d17ff5dd75b0eea2fa29d59c7bd`。
- ZIP 与解压内容、两层 manifest、安装器及输入快照均通过核对；被测提交的 Git archive 摘要为 `e1e9fa618952d05fd9f3728f481412666735f3e7fb569cfdcf8b1e0a3f628305`。另行确认 workflow 快照等于被测提交中的配置，20 份解压工作流日志与日志 ZIP 逐字节一致。

两个 job 的日志都记录 27/27 测试及六项离线集成通过。完整 job 还记录独立 writer 检查、三份语料全链路对照和最终 `none skipped`，见[完整检查日志](/home/user/MoonBit_Program/MoonXPT/docs/evidence/github-actions/run-42329267843/artifacts/public-corpus-42329267843-1/checks.log:5)。源码中的验证逻辑确实逐行比较 CSV、独立读取重建文件并比较声明元数据，并非仅检查退出码，见[validate_corpus.py](/home/user/MoonBit_Program/MoonXPT/tools/validate_corpus.py:42)。

SDK 回执、版本和摘要与锁文件一致。core 摘要明确标为官方 HTTPS 下载后的记录值，没有冒称独立发布校验值，见[SDK 回执](/home/user/MoonBit_Program/MoonXPT/docs/evidence/github-actions/run-42329267843/artifacts/public-corpus-42329267843-1/sdk-install.json:7)。固定 oracle 版本与安装记录相符；xport 的适配只修改 pandas 构造器调用，未修改格式算法，见[xport_compat.py](/home/user/MoonBit_Program/MoonXPT/tools/xport_compat.py:1)。

核对 C16 与审查提交之间的 58 个产品源码、接口、包配置、夹具及许可路径，内容没有变化。本地历史为 25 个连续、非空提交，C01—C16 为其中最初 16 个；审查提交直接追加在被测提交之后。当前 `origin/main` 跟踪被测提交，不能把本地后续归档提交称为该 run 测过的 HEAD；现有文档已明确这一点，见[归档边界](/home/user/MoonBit_Program/MoonXPT/docs/evidence/github-actions/run-42329267843/README.md:58)。

**发布阻断／发布门槛**

1. **产品版本标识尚未统一。** [moon.mod:3](/home/user/MoonBit_Program/MoonXPT/moon.mod:3) 为 `0.1.0`，但 [CLI 帮助:4](/home/user/MoonBit_Program/MoonXPT/cmd/moonxpt/main.mbt:4) 显示 `MoonXPT 0.1`。这不影响 XPT 解析，却使最终包、CLI 和拟建标签的版本身份不够明确。建议统一产品版本标识，确定最终候选提交，并记录针对最终候选及制品的验证；不要因此覆盖从输入文件保留的 SAS 来源版本元数据。

2. **尚无与最终候选绑定的两类正式制品及验证回执。** [handoff.md:32](/home/user/MoonBit_Program/MoonXPT/docs/handoff.md:32) 已承认完整评审源码包待生成；[.moonignore:4](/home/user/MoonBit_Program/MoonXPT/.moonignore:4) 排除了 CI 和 tools，这是库包过滤策略，不能据此声称提供了完整评审源码。现有 `_build/publish/any07557-moonxpt-0.1.0.zip` 有 80 项，未含 tools、CI 或新证据；其中 README 等七份文档也与当前工作树不同。它不是当前提交的最终候选制品。建议从选定提交重新生成使用者库包与完整源码包，登记提交、清单、字节数及 SHA-256，分别解压验证构建、CLI 小夹具和公共消费方。库包内的 README 还应明确 tools 命令需完整仓库，避免指向被过滤文件的本地链接。

3. **Mooncakes 发布身份尚未闭合；这是库包发布门槛。** [moon.mod:1](/home/user/MoonBit_Program/MoonXPT/moon.mod:1) 使用 `any07557/moonxpt`，但没有 repository 字段；[reproduction.md:40](/home/user/MoonBit_Program/MoonXPT/docs/reproduction.md:40) 明确该名称目前只是本地模块名。真实远程仓库已经存在，旧的“尚无远程地址”理由不再适用于最终包。建议填入实际 repository，核实发布账号对该命名空间的控制权及版本占用情况，再准备发布。当前 workspace 消费方成功不等于 registry 安装成功。此项不否定 GitHub 源码验收，也不应写成核心实现 bug。

**非阻断问题**

4. **成员名大小写规则的措辞有歧义。** [README.md:81](/home/user/MoonBit_Program/MoonXPT/README.md:81) 称成员名大小写不敏感；[reader.mbt:35](/home/user/MoonBit_Program/MoonXPT/reader.mbt:35) 的行数提示确实归一化大小写，但 [export 选择:342](/home/user/MoonBit_Program/MoonXPT/cmd/moonxpt/main.mbt:342) 使用精确字符串比较。用户可能据此预期 `--member oracle` 能选择 `ORACLE`。建议明确该声明只适用于 `--rows`，或统一成员选择行为并补充聚焦验证。这是局部 CLI／文档契约问题，不足以推翻现有大样本验收。

5. **oracle 的长期复现固定到版本，尚未固定安装制品摘要。** [requirements-oracle.txt:2](/home/user/MoonBit_Program/MoonXPT/tools/requirements-oracle.txt:2) 固定版本，[verify_release.py:123](/home/user/MoonBit_Program/MoonXPT/tools/verify_release.py:123) 从 PyPI 无缓存安装，但没有 wheel hash 锁定。现有版本回执和日志足以支持本次已发生的验收；未来源站可用性与同版本制品身份则是另一层保证。建议后续保存 wheel 摘要或下载清单。Python oracle 不进入产品运行依赖，此项不是当前核心产品发布阻断。

**已公开兼容限制与未覆盖范围**

- 620,612 单元格及 0 ULP 结论可信，但三份 NHANES 输入均为数值列：46、21、4 列，没有字符列。字符、CP1252、多成员和特殊缺失的证据来自独立小夹具、底层适配及向量，见[夹具检查](/home/user/MoonBit_Program/MoonXPT/tools/test_fixtures.py:21)和[writer 检查](/home/user/MoonBit_Program/MoonXPT/tools/check_writer.py:8)。不能把三份调查文件外推为所有 V5 布局或真实字符语料的全面覆盖。
- Linux x86_64 native 是已验证平台；V8、其他后端、其他编码和外部值标签目录不属于当前承诺。严格尾部策略、trim 可能丢歧义空白行、Double 低位损失和跨文件崩溃原子性限制已经公开，见[兼容矩阵](/home/user/MoonBit_Program/MoonXPT/docs/compatibility.md:3)。这些不是应追加为 P0 的缺陷。
- 本次云端入口执行 native debug 检查，没有请求 benchmark；百万行 release 性能数字属于既有本地实验，不能归入该云端 run，见[check.py:20](/home/user/MoonBit_Program/MoonXPT/tools/check.py:20)及[benchmarks.md:3](/home/user/MoonBit_Program/MoonXPT/docs/benchmarks.md:3)。
- MIT、第三方说明、core LICENSE/NOTICE 和夹具来源均在仓库及现有库包内，未发现当前源码分发的明确许可阻断。现有声明以源码分发为准，没有原生二进制发布证据，见[THIRD_PARTY.md:17](/home/user/MoonBit_Program/MoonXPT/THIRD_PARTY.md:17)。
- 独立读取远端 API 时，tags 与 releases 均为空。赛事官网本次仍未提供可读当期规则，无法确认十一月赛程、表单或资格要求；[contest.md:30](/home/user/MoonBit_Program/MoonXPT/docs/contest.md:30) 将其列为待核实项是准确的。赛事准备与技术验收应分别结案。

本次未确认声明支持范围内存在足以阻断发布的核心读写、数值或交换实现缺陷。**建议先关闭最终版本与制品缺口，完成包元数据及发布身份核对，再提交具体 Release 候选供授权。** 文档归档追加不必自动重跑全部产品测试，但必须继续准确标注旧 run 的被测提交；正式 Tag/Release、Mooncakes 与赛事提交仍需分别取得授权。
