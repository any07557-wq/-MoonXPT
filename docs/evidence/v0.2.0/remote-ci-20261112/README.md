# v0.2.0 远端 CI 验收（2026-11-12）

结论：**四类非 SAS CI 实际通过，READY_WITH_SAS_VALIDATION_BLOCKED**。
C05、SAS→MoonXPT 和 MoonXPT→SAS 仍 blocked。两个 run 的 SAS job 均 skipped，
不计为 SAS 验证成功，也不宣称五类 CI 全部通过。

## 授权与受验源码

用户明确授权仅推送开发分支并运行 CI。实际执行
`git push -u origin work/v0.2.0-boundary`，退出码 0，新分支创建成功，跟踪关系已建立。
仓库为 `https://github.com/any07557-wq/-MoonXPT.git`，两个 run 的受验源码均为
`b0d622d7f1e555b9c32cebf991682d9a7d25de0f`。完整操作回执见 [operations.json](operations.json)。

手动运行参数为 `real_corpus=true`、`sas_interop=false`。没有修改 workflow、GitHub 设置，
没有合并 main、创建 v0.2.0 Tag/Release、发布 Mooncakes 或提交赛事。
远端 main 仍为 `bad7ec0158c5585b3a2ba1b0fe99528cfa1ffd7a`，
v0.1.0 tag 对象仍为 `51ab97700bdaf15e225f432ec1bf27c94dc70a8f`，
其源码仍为 `2cddd31bb8b88648f619969dbb4fe195051735b4`。

## GitHub 实际运行

| Run | 事件 | 结论 | artifacts | 原始日志文件 |
|---|---|---|---:|---:|
| [43167635468](https://github.com/any07557-wq/-MoonXPT/actions/runs/43167635468) | push | success | 3 | 30 |
| [43167683870](https://github.com/any07557-wq/-MoonXPT/actions/runs/43167683870) | workflow_dispatch | success | 4 | 41 |

| Job | push run | 手动完整 run |
|---|---|---|
| offline-core | success | success |
| fixtures-interop | success | success |
| public-corpus | skipped（非手动事件） | success |
| sas-interop | skipped / C05 blocked | skipped / C05 blocked |
| release-repro | success | success |

GitHub API 当时仍将 workflow 显示为 `MoonXPT compatibility`；workflow 文件为
`.github/workflows/ci.yml`，ID 409986884。受验 job、checkout commit 与全部 95 份记录源码的
SHA-256 均已核对，未把旧版本的运行当作本次证据。

## 实际验证范围

- 两个 offline-core 和两个 release-repro 的原始测试日志均为 **81/81**，同时通过原集成、
  新 API/CLI、资源限制与 v0.1.0 保护检查。
- ReadStat（通过 pyreadstat）和 Python xport 双向互操作实际通过声明范围。ReadStat 单成员、
  Python xport 单/多成员分别验证；两家便利 reader 的短尾/空白行缺失、字符原始字节不可见、
  ReadStat 多成员等限制仍原样记录，不以裁剪数据、放宽容差或 SAS 替代取得通过。
- public-corpus 重新下载 SHA-256 固定的 DEMO_J、BMX_J、GLU_J，分别核对
  425,684、182,784、12,144 个单元格，共 **620,612**，声明元数据一致，最大实测 **0 ULP**。
- 7 个成功 job 各有独立前缀的 SDK 安装回执：官方归档键 `0.10.15+943464bfa`，
  archive/core hash 与受验 commit 的 lock 一致，`download_cache_reused=false`、
  `existing_sdk_read=false`。两个互操作 job 和语料 job 均在新 venv 安装固定 oracle。
  使用 GitHub-hosted ubuntu-24.04 job；不推断各 job 使用不同物理机器。
- release-repro 在该远端 job 内再次干净克隆确切 commit，不复用项目 `_build/.cache`。
  原始内部回执的“共享现有 SDK/宿主”文字描述的是该 job 内部的克隆步骤；外层安装步骤与
  `offline/sdk-install.json` 证明该 SDK 是本 job 新装。保留原文，不改写原始回执。

## 原始证据与 SHA-256

两个 `raw-*.zip` 各自保留原始 run/jobs/artifacts API JSON、完整 `logs.zip`、所有 artifact
ZIP 字节以及本地校验回执。`BUNDLE-MANIFEST.json` 是归档新增清单，不冒称 CI 原始输出。
原始 API 中的 `digest` 与下列下载 ZIP 的 SHA-256 逐项相等，7 个 artifacts 的内部
manifest、字节数、源文件身份及 SDK 回执也已验证。

| Run | Artifact job | 字节数 | SHA-256 |
|---|---|---:|---|
| 43167635468 | fixtures-interop | 23456 | `e93acec24915f65fe2f82b81b33ff184729ccb177478a9acec6a927c2c3fab04` |
| 43167635468 | offline-core | 16440 | `dc29fe93a5781e3d8dc264bab6ba5aced4c98bac97e3bc67092ee19a42454ac1` |
| 43167635468 | release-repro | 18711 | `4538d845acdee03c0ff7883591997509a2df81dae4df47d6d22f73e064f25d36` |
| 43167683870 | fixtures-interop | 23447 | `50c2bb8abb46b4f17456f80613efd3b3a6fbde30156e5b3b1a176a12f0888b66` |
| 43167683870 | offline-core | 16357 | `48d1c6476b65c03eb392b63bb62f06e45d02cc9ad11fbe75d34e94f12294e864` |
| 43167683870 | public-corpus | 8893 | `7b4fbfffddfc279f4ec8bc49d67b0738fe863a87064ecd413bdd83a18aab1129` |
| 43167683870 | release-repro | 18705 | `f4a8eebdebb0f67e8ec9c4dfe94d730268be99818b4ddb4cbe2b48b0a0eaa989` |

机器回执见 [result.json](result.json)。[collector.py](collector.py) 保留当时采集和初验方法，
标准库离线复核入口为 [verify.py](verify.py)：

```sh
python3 tools/verify_v020_evidence.py docs/evidence/v0.2.0/remote-ci-20261112
python3 docs/evidence/v0.2.0/remote-ci-20261112/verify.py
```

后一个命令需要本仓库保留受验 commit 的 Git 对象，只检查归档与已记录结果，不联网，
不重新执行 SDK/oracle/CI。全部文件及两个原始 bundle 的 SHA-256 由 `manifest.json` 覆盖。
此目录及主报告的远端验收追加内容在受验 commit 之后生成，归档准备时尚未提交或推送；
它们不是已受验 commit 的组成部分。旧阶段证据及失败记录不覆盖。

## 证据提交前审查追加（2026-11-12）

待提交范围收拢为本目录及 `docs/validation-report-v0.2.0.md`；原有申报书和此前证据不纳入
或改写。递归凭据检查见 [扫描回执](sensitive-scan.json)，包含完整日志、全部嵌套 ZIP，
未发现未脱敏匹配；具体规则与方法边界见 [扫描入口](scan_sensitive.py)。如需重新检查，
可直接运行该脚本，无参数时只输出结果，不改写已归档回执。

[发布准备初审](release-review.md) 记录已核对事项及正式发布前待办，包括库 README 旧描述、
0.2.0 最终制品/消费方验收、Mooncakes 独立迁移。v0.1.0 Release 正文和七个附件元数据
已与原发布记录只读比较，见 [审查回执](review.json)。本次提交前审查时，本地提交及推送
分别待授权；实际执行以其后的 Git 历史及授权回执为准。
