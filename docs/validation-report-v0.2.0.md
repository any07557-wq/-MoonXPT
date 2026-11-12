# MoonXPT v0.2.0验证报告

开发目标0.2.0，未发布。审计始于2026-11-11，本轮结果于2026-11-12归档。
开始HEAD为bad7ec0158c5585b3a2ba1b0fe99528cfa1ffd7a，稳定版v0.1.0源码为
2cddd31bb8b88648f619969dbb4fe195051735b4，annotated tag对象为
51ab97700bdaf15e225f432ec1bf27c94dc70a8f。原16笔历史、tag及旧证据保留。

## 阶段与证据

| 阶段 | 状态 | 验证内容 |
|---|---|---|
| C01 | passed | C00实际仓库/SDK/布局审计、官方TS-140、EOF问答与固定源码，ADR-003；evidence/v0.2.0/c01 |
| C02 | passed | B01–B20，47/47及原离线集成；共享resolver、宽度/溢出/候选/hint；c02 |
| C03 | passed | M01–M23，70/70及原集成；全局完整路径、候选缓存、seek/有界非seek；c03 |
| C04 | passed | A01–A18，78/78、14个独立布局fixture、原集成与消费方；c04 |
| C05 | blocked | 用户明确无合法SAS环境/runner。程序与MoonXPT输入已准备，S01–S14未由SAS执行；c05 |
| C06 | prepared_not_verified（待最终追加） | 下述双向/语料/资源结果已通过；先提交门禁代码，再从该确定提交执行R14并追加最终回执 |

既有305个证据/测试/夹具/根报告逐字节核对通过；兼容矩阵、references、progress原文只追加。
用户原有未跟踪申报书不修改，不纳入开发提交。所有原始失败记录保持分开，未用mock替代外部验证。

## 实际oracle与双向矩阵

固定SDK为moon0.1.20261012/748b63c、moonc0.10.15+943464bfa。oracle与依赖固定于
tools/requirements-oracle.txt、tools/oracles-v0.2.0.json，实际Python/包版本、适配器及动态库hash
记录在c06/interop/result.json中。本地使用已有固定SDK、oracle与验hash语料，不声称全新安装。

| 方向 | 状态 | 实际范围与限制 |
|---|---|---|
| I01 SAS→MoonXPT | blocked | 无真实SAS，准备脚本不计作通过 |
| I02 MoonXPT→SAS | blocked | 同上，无SAS LOG/PROC COMPARE结果 |
| I03 ReadStat→MoonXPT | passed | pyreadstat1.3.7独立新写单成员，所有行/列值与已声明元数据核对 |
| I04 MoonXPT→ReadStat | passed（单成员支持范围） | 4个独立单成员文件、数字/缺失掩码与暴露元数据；不使用切片冒充多成员 |
| I05 Python xport→MoonXPT | passed | 3.6.1独立写单成员及2个不同schema成员；全部行列、CP1252及元数据 |
| I06 MoonXPT→Python xport | passed（正常支持范围） | 4个单成员及4成员整文件，所有成员/行列；低层API另验28类缺失 |

ReadStat与pyreadstat只计一个实现家族。已安装pyreadstat1.3.7的vendored源码属于
Roche/pyreadstat commit e6e23bc0021875f35fccc3c2707c3e5151c130bb；不是C01审阅的
上游8ce32a11c248225dd4ccaccbcadd24214c5da46f构建。不声称运行过独立上游ReadStat CLI，
也不声称仅凭版本文本证明了二进制的可重建构建链；实际模块hash供识别。

明确保留的not_supported_by_oracle：

- 两个便利reader都裁剪字符尾空格，不能证明字符原始存储字节。测试对其明确的字符串视图
  作逐值比较，不通过统一trim源数据制造相等；原始字符另由作者字节向量验证。
- pyreadstat将特殊缺失归一NaN；只验证掩码。Python xport低层ibm_to_ieee及tag对象
  独立验证28种标记（含普通缺失），DataFrame不充当tag证据。
- 两个实际固定reader均把SHORT的2行读成1行、FULLBL的1行读成0行，原样记录为不支持。
  上游ReadStat已有宽空白行修复，当前vendored构建没有；不能用源码审阅替代实际行为。
- ReadStat直接读取正常4成员文件实际返回124行和首成员列，不计为多成员成功。
  Python xport的正常4成员检查与上述风险输入分开，未隐藏失败成员。
- 严格padding/截断验证不能靠便利reader是否报错证明；12项边缘结果逐项记录，MoonXPT默认
  拒绝损坏及非标准NUL，NUL兼容仅显式opt-in。间隙/重排及完整HFP范围由规范向量补证。

## 测试ID与实际检查

| 测试 | 状态 | 命令/证据 |
|---|---|---|
| B01–B20、M01–M23、A01–A18 | passed | 原27组未改，当前78/78；test_boundary_cli.py及14份fixture hash |
| R01–R10 | passed（上述限制单列） | test_interop_v020.py；四个非SAS方向，所有正常成员/行列、缺失/元数据及边缘行为 |
| R11 | passed | check.py --oracle --corpus，3份固定NHANES，620612单元格及已声明元数据，实际max ULP0 |
| R12 | passed | 原seed20261104的79截断/256变异/8定向错误；新增6组资源输入，预算4且标记8/64/512 |
| R13 | passed（有界范围） | M15/M19，chunk=1/7/79/80/81/4096，seek与非seek，回放超限明确失败 |
| R14 | not_run（本段归档时） | 提交实现后用reproduce_v020.py从确切commit克隆，结果在最终追加章节登记 |
| R15 | passed | verify_v010_baseline.py：305份不变、3份文档原文保留、tag/祖先历史核对 |

6组资源输入1520–246800字节，GNU time的debug CLI最大RSS实测2784–2828KiB，单组耗时
和输入hash单独登记。这是候选预算拒绝实验，不是新的release吞吐或普适内存保证。
数值容差未放宽，三份真实语料均为数值列；字符/特殊缺失证据不能借用它们。

## CI配置与复现入口

五类job为offline-core、fixtures-interop、public-corpus、sas-interop、release-repro，固定
官方SDK/Python和Actions commit，成功失败均保存证据。public-corpus手动联网；SAS同时要求
手动授权及显式启用的合法self-hosted runner，目前不存在/未启用。配置通过actionlint1.7.12
静态检查，shellcheck未安装因而未运行；本轮未push，新的远端CI均not_run。

```sh
python3 tools/check_v020.py --mode offline --evidence-dir ../v020-offline-new
bash tools/setup_oracles.sh
.cache/venv/bin/python tools/check_v020.py --mode interop --evidence-dir ../v020-interop-new
.cache/venv/bin/python tools/fetch_corpus.py
.cache/venv/bin/python tools/check_v020.py --mode corpus --evidence-dir ../v020-corpus-new
python3 tools/reproduce_v020.py --commit HEAD --evidence-dir ../v020-clean-new
```

每次使用新证据目录；脚本失败不覆盖旧结果。clean只验证已提交源码，无项目_build/.cache
复用，但使用已有固定SDK，共享宿主OS/内核，不计新机器或全新工具链安装。
所有本版本证据单独归档，旧27组及620612历史报告不覆盖。尚未push、创建v0.2.0标签、
发布GitHub Release/Mooncakes或提交赛事。


## C06最后两项回归修正（2026-11-12）

真实文件的Input必须以构造时的当前位置作为逻辑原点。新增带8字节前缀的双成员真实文件
回归，验证两成员row offset为880/1680；C03新增seek适配漏掉原点的问题已修正。
另新增两项资源语义回归：max_rows不能删掉合法N/P候选来制造唯一解释；先保留完整格式
候选集合，多解仍报歧义，唯一行数超限才报E_V5_RESOURCE_LIMIT。资源上限不是作者行数证据。
修正前79组中1失败、81组中2失败的实际日志独立保留，修正后81/81与全部集成、双向oracle
及620612真实单元格回归重新通过。精确提交的clean checkout仍在代码提交后单独归档。


## 最终验收追加（2026-11-12）

**READY_WITH_SAS_VALIDATION_BLOCKED**。实际实现commit为
`69abb7dfa7b44dfc7dfc7d3e4e8b89addb50a48d`。C01–C04、C06现已passed，C05仍blocked。
R14已从该确定commit干净克隆实际通过：81/81、全部旧集成、新API/CLI与资源检查，
未复用项目构建缓存；SDK仍为既有固定版本，共享宿主OS/内核，不计新机器/SDK安装。

修正后的81/81、两家实现双向、620612单元格/声明元数据及max ULP0已重新验收；
305份旧材料、v0.1.0 tag及历史不变。用户未跟踪申报书3570字节，SHA-256为
abaa7cfe029c8067551560659dbda596f84040d3e06946e9dfd0f85acd291c38，未纳入提交。

SAS实际执行信息：可执行路径/版本/runner均无，S01–S14 blocked；后续需要合法XPORT
Engine、真实LOG/PROC CONTENTS/PROC COMPARE及编码环境，现有模板不能代替执行。
新远端CI均not_run，只有配置与本地入口通过。没有push、v0.2.0 tag、Release、Mooncakes
发布或赛事提交。最终文档提交的完整hash在交付回复及本地final-delivery.json登记。

最终回执、各阶段完整commit、fixture SHA、各oracle版本/验证方向与原日志位于
`docs/evidence/v0.2.0/final-20261112/`；此前阶段状态及失败记录保留，不覆盖。

## 远端 CI 验收追加（2026-11-12，用户授权后）

开发分支 `work/v0.2.0-boundary` 已推送到授权仓库
`https://github.com/any07557-wq/-MoonXPT.git`。两个实际运行均对应确切提交
`b0d622d7f1e555b9c32cebf991682d9a7d25de0f`，不是旧版本的运行记录：

- [Push run 43167635468](https://github.com/any07557-wq/-MoonXPT/actions/runs/43167635468)：
  offline-core、fixtures-interop、release-repro 全部 success；public-corpus 非手动事件因而 skipped。
- [手动 run 43167683870](https://github.com/any07557-wq/-MoonXPT/actions/runs/43167683870)：
  `real_corpus=true`、`sas_interop=false`，四类非 SAS job 全部 success。

两个 run 的 offline-core 与 release-repro 均实际通过 81/81。云端重新安装固定 oracle，
完成 ReadStat/pyreadstat 单成员及 Python xport 单/多成员双向验证；此前声明的 oracle
限制保持不变。三份固定 SHA-256 的 NHANES 文件共 620612 单元格和声明元数据再次通过，
最大实测差异 0 ULP。

7 个成功 job 的官方 SDK/core 均下载到各 job 独立新前缀，归档键
`0.10.15+943464bfa`，hash/版本与受验 commit 的 lock 一致；安装回执确认未读现有 SDK、
未复用下载缓存。release-repro 另从该 commit 干净克隆，不复用项目构建缓存。其原始回执中
“共享现有 SDK/宿主”描述的是远端 job 内部的克隆步骤，外层 SDK 安装回执和完整 Actions
日志补齐云端执行上下文；原始回执不改写，不推断每个 job 使用不同物理机器。

已下载两次运行的完整日志、全部 7 个 artifacts 和原始 API 元数据。每个下载 ZIP 的
SHA-256 与 GitHub artifact digest 一致；内部 manifest、每份回执覆盖的 95 个实现/配置文件
与受验 Git blobs 一致。原始文件及独立离线复核入口归档于
[remote-ci-20261112](evidence/v0.2.0/remote-ci-20261112/README.md)。

**READY_WITH_SAS_VALIDATION_BLOCKED** 保持不变。两个 SAS job 均 skipped；C05、S01–S14
及两个 SAS 方向仍 blocked，没有实际 SAS 执行或成功声明。此前 not_run/未 push 的记录
保留其当时含义，由本节追加最新证据。main、v0.1.0 Tag/Release 未变；本轮没有修改 workflow、
创建 v0.2.0 Tag/Release、发布 Mooncakes 或提交赛事。本次归档准备时，这批远端证据及文档
追加尚未提交或推送。

提交前已将候选范围收拢为上述远端证据目录及本报告；原证据索引和用户原有申报书不纳入。
递归凭据扫描、只读 v0.1.0 Release 核对和发布准备待办见
[提交前审查](evidence/v0.2.0/remote-ci-20261112/release-review.md)。本次提交前审查时，证据本地
commit 与后续 push 分别待明确授权；正式版本制品尚需单独整理和验收，不据此创建 Release。
