# 第二台机器与远端CI验收

状态日期：2026-11-06。用户确认第二台机器与GitHub仓库均尚未配置。
本阶段准备配置、可移交入口和本地检查，不把它们计为外部运行通过。
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
| checkout | v4.4.0 | 11d5960a326750d5838078e36cf38b85af677262 |
| setup-python | v5.6.0 | a26af69be951a213d495a4c3e4e4022e16d87065 |
| upload-artifact | v4.6.2 | ea165f8d65b6e75b540449e92b4886f43607fa02 |

官方来源：[checkout](https://github.com/actions/checkout/releases/tag/v4.4.0)、
[setup-python](https://github.com/actions/setup-python/releases/tag/v5.6.0)、
[upload-artifact](https://github.com/actions/upload-artifact/tree/v4.6.2)、
[Python分发清单](https://github.com/actions/python-versions/blob/main/versions-manifest.json)。

远程仓库尚无地址；push与外部执行的授权尚待确认。本次不创建仓库、不push、不发布。
具备目标与授权后，先执行常规job，再手动选择real_corpus，保留两类job的实际run URL、
完整源码commit、运行attempt、结论和下载的artifact，最后归档；本地预演不替代这些记录。

## 当前验收状态

| 层次 | 状态 | 证据 |
|---|---|---|
| 原开发环境 | 通过 | [C15/C16记录](evidence/README.md) |
| 同机隔离全新安装 | 通过 | [全新安装记录](evidence/independent-install/README.md) |
| 新CI入口的本地检查/预演 | 进行中 | 完成后单独登记，不能计作远端通过 |
| 第二台机器 | 待配置、未运行 | 尚无独立主机 |
| 远端CI | 待配置、未运行 | 尚无GitHub仓库/run URL |

后续版本统一、正式两类zip、v0.1.0标签与Mooncakes准备另行推进；保留当前历史与失败材料。
