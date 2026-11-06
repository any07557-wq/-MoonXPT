# 复现与 CI

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
触发的真实语料任务分开；语料缓存键绑定清单，使用时仍验 hash。
上述安装验证为后续 CI 提供已实测入口；本次没有修改 CI 配置，也未运行远端 Actions。
远程 runner、版本标签、两类源码制品的一致性仍待后续收尾。
push、Release、Mooncakes 发布和赛事提交等待证据齐全及明确授权。
