# 第二台机器与远端CI验收

状态日期：2026-11-07。[公开仓库](https://github.com/any07557-wq/-MoonXPT)已建立，
[Run 42329267843](https://github.com/any07557-wq/-MoonXPT/actions/runs/42329267843)
attempt1的offline和public-corpus均成功，被测commit为
`0dc4b95e001bc86253926be66321eb0e0f71b4db`。原始ZIP与日志已[归档](evidence/github-actions/run-42329267843/README.md)。
2026-11-06尚未配置及本地超时的记录继续保留；云端成功没有覆盖它们。
P0与冻结基线 `1516dfd033d4ecee1bf0fd5cb35c9ec77762a774` 不变；既有证据不覆盖。

## 同一个验证入口

`tools/verify_release.py` 测试当前仓库的**已提交HEAD**，每次新建临时目录：

1. 记录commit、tree和Git archive摘要，提取不含缓存的源码。
2. 调用归档内安装器，按tools/toolchain.json的编译器版本键安装全新SDK/core并校验。
3. offline执行格式、检查、27组测试、构建、离线集成和公共消费方。
4. full另建全新venv，无pip缓存安装固定oracle，重新下载三份语料并验SHA-256，执行完整对照。

入口不复用SDK、源码构建缓存、oracle或语料；结束后清理临时SDK/源码，保留证据目录。
它不隔离宿主文件系统，也不创建新机器。执行在哪台机器，证据就只属于那台机器。
未提交改动不参与Git archive；验证脚本自身必须与已提交版本一致，否则失败。

证据目录必须是新路径，重复路径会拒绝覆盖。result.json记录每一步的命令、时间、状态、
退出码、主机OS/架构/内核/Python及可用的Actions运行上下文。日志同时保存stdout/stderr；
SDK回执、锁文件和依赖版本另外保留；manifest.json登记文件SHA-256。失败退出非零并保存
failure.log，不把未执行的完整检查计作通过。若进程被强制终止或磁盘不可写，不能保证完成回执。

## 第二台机器操作

需要实际独立的Linux x86_64主机或虚拟机。基础依赖：Git、C编译器及libc开发文件、
CA证书、Python 3.14.4及venv/ensurepip，能够访问官方MoonBit、PyPI及CDC HTTPS来源。
Python不是产品运行依赖，这里固定它是为安装oracle。Ubuntu 24.04是计划CI基础系统；
本机曾通过的OS不能直接推断其结果。

无须先公开仓库，可从本机创建Git bundle，经已有获准渠道传到第二台机器：

```sh
# 在开发仓库中：先提交本次验证所需文件；只读生成历史与源码的传输文件。
mkdir -p .cache
git bundle create .cache/moonxpt-validation.bundle HEAD refs/heads/main
git rev-parse HEAD
git bundle verify .cache/moonxpt-validation.bundle
```

在第二台机器上：

```sh
git clone /path/to/moonxpt-validation.bundle MoonXPT
cd MoonXPT
git rev-parse HEAD  # 必须与移交时的完整hash一致
python3.14 -c 'import sys; assert sys.version_info[:3] == (3, 14, 4), sys.version'
python3.14 tools/verify_release.py --mode full --evidence-dir ../moonxpt-full-evidence
```

SDK无需预装；工具链地址始终从锁文件的archive_version取值，不从moon版本输出推导。
从Git bundle克隆会得到完整历史；它是本地验证传输材料，不代替后续正式库包与完整源码zip。
失败时保留原证据，修复基础环境后用新的evidence-dir重跑，不删除失败记录。

验收时核对source_commit、实际机器来源、result=PASS、SDK版本/hash、全部阶段退出码0，
checks.log含27/27、三份语料及620,612单元格/元数据对照、无请求项跳过。
将整份证据目录与操作者确认的独立主机说明一并移交，不能仅提供一张成功截图。

## GitHub Actions

`.github/workflows/ci.yml` 的两个job分开运行：

| job | 触发 | 内容 |
|---|---|---|
| offline | push、pull_request、workflow_dispatch | 新SDK；不安装oracle，不下载真实语料；执行离线检查 |
| public-corpus | 手动workflow_dispatch且real_corpus=true | 新SDK、新oracle、新语料；完整对照 |

“离线”指检查内容不依赖外网语料；checkout、Python配置和SDK安装仍需要网络。
两个job固定ubuntu-24.04和Python 3.14.4，Actions按已核对的完整commit固定。
删除旧语料缓存步骤，完整验收每次重新下载；每个job保留30天证据artifact，名称含run ID
与attempt，成功失败均尝试上传。若checkout/Python配置在入口启动前失败，需保留Actions
自身日志；不能因缺少result.json就判通过。

| Action | 固定版本 | commit |
|---|---|---|
| checkout | v7.0.1 | 3d3c42e5aac5ba805825da76410c181273ba90b1 |
| setup-python | v7.1.0 | 6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 |
| upload-artifact | v7.0.2 | cf430e030ddbb5b0abf93d22962f4752f3646cd9 |

官方来源：[checkout](https://github.com/actions/checkout/releases/tag/v7.0.1)、
[setup-python](https://github.com/actions/setup-python/releases/tag/v7.1.0)、
[upload-artifact](https://github.com/actions/upload-artifact/releases/tag/v7.0.2)、
[Python分发清单](https://github.com/actions/python-versions/blob/main/versions-manifest.json)。

本次运行已按上述两种模式完成。已保存实际run/job URL、完整源码commit、attempt、
结论及下载artifact，核对13+19份包内manifest记录和GitHub ZIP摘要。
本轮只读取已有运行并归档，没有修改或触发工作流，也没有追加push或发布。

## 当前验收状态

| 层次 | 状态 | 证据 |
|---|---|---|
| 原开发环境 | 通过 | [C15/C16记录](evidence/README.md) |
| 同机隔离全新安装 | 通过 | [全新安装记录](evidence/independent-install/README.md) |
| 新CI入口的静态/失败处理检查 | 通过 | [检查记录](evidence/ci-preparation/local-checks.json) |
| 新CI入口的两类本地预演 | 未通过 | 均在SDK下载超过600秒时失败，未进入测试；[原始记录](evidence/ci-preparation/README.md) |
| 独立云端runner | 通过 | Ubuntu24.04/Azure，与开发机WSL/Ubuntu26.04不同；[云端证据](evidence/github-actions/run-42329267843/README.md) |
| 远端offline CI | 通过 | Run42329267843/attempt1，27/27及离线集成 |
| 远端public-corpus CI | 通过 | 同run，27/27、620612单元格及元数据，最大ULP0 |
| 人工指定的第二台SSH主机 | 未另行执行 | 不纳入本次云端结论 |

以上成功严格绑定被测commit；后续文档归档提交不是该run验证的HEAD。
后续独立发布审查、版本统一、正式两类zip、v0.1.0标签与Mooncakes准备另行推进；
Tag/Release、Mooncakes及赛事提交按用户授权执行。
