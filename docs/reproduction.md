# 复现与 CI

产品模块与CLI版本为 **0.1.0**；消费方依赖使用 `any07557/moonxpt@0.1.0`。
下面的MoonBit SDK版本是构建依赖，独立于产品版本；完整约定见[版本说明](versioning.md)。

固定版本：`tools/toolchain.json`。已验证 `moon 0.1.20261012 (748b63c)`、
`moonc v0.10.15+943464bfa`，Linux x86_64 native，C 编译器与 Python 3.14.4。
产品可执行文件和核心库运行不需要 Python。

安装固定 SDK 需要 Python 3.12+（标准库 tarfile 的 data 过滤器）、HTTPS 及 C 编译器。
使用尚不存在的绝对路径，不覆盖已有安装：

```sh
moonxpt_sdk_prefix="$(pwd)/.cache/sdk-fresh"
bash tools/install_toolchain.sh "$moonxpt_sdk_prefix" --receipt .cache/sdk-install.json
export MOON_HOME="$moonxpt_sdk_prefix"
export PATH="$moonxpt_sdk_prefix/bin:$PATH"
moon version --all
```

归档版本键为编译器版本 `0.10.15+943464bfa`；安装器重新下载官方归档与 core，
核对固定 SHA-256 和版本，再编译 native core。没有 latest 回退。
core 摘要来源与原 403 调查见[安装报告](toolchain-installation.md)。

```sh
python3 tools/check.py
# 可选：固定 oracle 环境和真实语料，下载失败或 hash 不符均失败
bash tools/setup_oracles.sh
python3 tools/fetch_corpus.py
.cache/venv/bin/python tools/check.py --oracle --corpus
# 可选：独立的合成负载实验
python3 tools/check.py --benchmarks
```

默认检查不联网：格式、静态检查、单元测试、native 构建、小型独立夹具、
CLI、错误路径和外部消费方。oracle 只用于显式验证任务；Python xport 的
pandas 兼容适配及局限见 validation-report.md。不会把缺依赖的 oracle 自动跳过。

公共包无需远程发布即可接入：建立 `moon.work`，`members` 同时列出本仓库
及消费方模块；消费方 `moon.mod` 声明 `import { "any07557/moonxpt@0.1.0" }`，
`moon.pkg` 声明 `import { "any07557/moonxpt" @xpt }`。
`tools/test_consumer.py` 实际建立独立模块并验证 writer/reader，只使用公共 API。
命名空间是当前本地模块名，并未声明 Mooncakes 账号或发布状态。

```sh
# 先确保所需文件都已 commit；只提取 HEAD，不复制构建缓存。
.cache/venv/bin/python tools/reproduce_clean.py --corpus
```

干净复现保留固定已安装工具链；oracle 使用调用解释器中已有固定版本依赖，
真实输入仅从缓存复制并再次验 hash，不复制任何构建输出或虚拟环境。
它证明源码干净重建，不能证明远端安装服务可用。

2026-11-05 发布收尾已修复原安装器的版本键错误：此前用 moon 构建工具版本构造
归档 URL 得到 403，改用对应编译器发布版本后全新下载成功，SDK 身份没有改变。
同机 bubblewrap 隔离运行隐藏整个开发者 HOME，从冻结 C16 的 Git archive 开始，
重新安装 SDK 与无缓存 PyPI oracle、重新下载三份语料；完整检查通过且无跳过。
27 组测试和 620,612 单元格对照均通过。完整日志、固定安装器快照、两次前置失败见
[独立安装证据](evidence/independent-install/README.md)。

如需重跑该冻结基线验证，可运行 `python3 tools/verify_independent_install.py`。
该实验脚本要求 bubblewrap、可用的用户命名空间和 Python venv；隔离挂载按本次
WSL DNS 布局配置，其他宿主需核对 DNS 挂载。结果保存在 `.cache/independent-install/`。
它共享宿主 Linux 内核、基础 OS、DNS 和网络代理，不代表第二台机器或新 OS 镜像验证。

`.github/workflows/ci.yml` 配置 Linux 托管 runner：普通离线小夹具检查与手动
触发的真实语料任务分开；完整验收每次重新下载并验证固定hash，不使用语料缓存。
后续CI已接入 `tools/verify_release.py`，固定正确版本键与Python 3.14.4，按完整commit固定
Actions，并在成功/失败后尝试保存逐阶段日志和回执。完整语料任务不复用语料或oracle缓存。
第二台机器可使用同一入口与Git bundle移交；具体步骤及证据要求见
[外部验收说明](external-verification.md)。
2026-11-06本地两类入口预演均因SDK下载超过600秒上限而失败，未进入新的构建/测试；
静态与失败处理检查通过。完整记录见[CI准备证据](evidence/ci-preparation/README.md)，
该历史失败没有改写。2026-11-07的Run42329267843/attempt1在GitHub托管Ubuntu24.04
分别完成offline和public-corpus，均success：新SDK、新oracle/语料，27组及620612单元格
全部通过，无跳过。原始记录和可离线重验的ZIP见[云端归档](evidence/github-actions/run-42329267843/README.md)。
被测commit为0dc4b95e001bc86253926be66321eb0e0f71b4db，后续归档提交不属于该run的测试对象。
版本标签、两类源码制品的一致性仍待后续收尾；Release、Mooncakes发布和赛事提交尚未执行。
