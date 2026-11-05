# 复现与 CI

固定版本：`tools/toolchain.json`。已验证 `moon 0.1.20261012 (748b63c)`、
`moonc v0.10.15+943464bfa`，Linux x86_64 native，C 编译器与 Python 3.14.4。
产品可执行文件和核心库运行不需要 Python。

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

官方安装脚本已实际读取。按其历史 URL 形式请求固定归档时，2026-11-04 的
HEAD 和 Range GET 均 HTTP 403，未成功重新安装该版本。
`bash tools/install_toolchain.sh NEW_ABSOLUTE_PREFIX` 是失败即停止的安装入口，
不会替换现有工具链，不回退到 latest；历史归档下载仍属外部未验证项。
可先使用已具备该固定版本的环境运行本地检查。

`.github/workflows/ci.yml` 配置 Linux 托管 runner：普通离线小夹具检查与手动
触发的真实语料任务分开；语料缓存键绑定清单，使用时仍验 hash。
CI 的安装步骤在官方403未解决前会失败；不标作已通过，也未运行远端 Actions。
没有远程仓库、push、Mooncakes 发布或赛事提交授权，本次只交付本地配置与材料。
