# 固定工具链安装调查（发布收尾）

冻结产品基线：`1516dfd033d4ecee1bf0fd5cb35c9ec77762a774`。
调查与运行日期：2026-11-05；归档日期：2026-11-06。P0源码及原有16笔提交不变，CI配置暂不修改。

## 403原因与正确入口

原安装入口错误地将构建工具版本 `moon 0.1.20261012+748b63c` 当作归档版本键。
官方安装脚本的版本参数对应编译器发布版本，正确键为 `0.10.15+943464bfa`。

| 请求 | 实际结果 |
|---|---|
| binaries/0.1.20261012%2B748b63c/... | 403，S3 AccessDenied；部分复查遇TLS EOF，单独记录 |
| binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz | 206，按请求只读512字节，完整长度100080035 |
| 同版本原生包 .tar.gz.sha256 | 200，官方归档SHA-256可取得 |
| cores/core-0.10.15%2B943464bfa.tar.gz | 206，按请求只读512字节，完整长度1880333 |
| 同core的 .sha256 | 403；不宣称存在可用官方独立core摘要 |
| 官方GitHub v0.10.15+943464bfa发布页及Wasm资产 | 可读取；保留为候选来源，实际采用上述原生归档 |

仅凭错误路径的AccessDenied不能区分对象不存在与ACL拒绝；已能确定的是版本键使用错误，
修正键可取得同一冻结编译器，且官方per-file清单中的moon/moonc摘要与固定版本身份一致。
没有切换latest、升级编译器或取消版本检查。

官方来源：

- [安装入口](https://cli.moonbitlang.com/install/unix.sh)
- [固定版本原生包](https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz)
- [官方原生包摘要](https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz.sha256)
- [固定core](https://cli.moonbitlang.com/cores/core-0.10.15%2B943464bfa.tar.gz)
- [官方GitHub发布](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.15%2B943464bfa)

原生包官方摘要：`24b93a5409d2a4fb8e3d1b84b473f27b63476cef4418094764df96cb26b03c09`。
core固定摘要：`96d30f4dbcc6a9e1736ef26fbdd0e8fb0e97cb01d50e55d2a0072208b8061ae5`，
由官方HTTPS归档首次下载后记录，不冒充官方发布的独立校验值。
后续下载同时与本地锁定值比较，拒绝变化。

HTTP响应、请求失败、GitHub源码说明和文件摘要见
[原始调查材料](evidence/toolchain-discovery/manifest.json)。请求结果按运行目录分别保存，
失败请求不写作零结果，也不拿旧body文件冒充新响应。

## 独立安装的验证边界

`tools/verify_independent_install.py` 使用bubblewrap创建隔离用户空间：

- 开发者整个HOME隐藏，前置检查确认既有MoonBit、pyreadstat、xport、pandas、numpy不可见。
- 测试源码由冻结C16的Git archive提取，不复制_build、SDK、venv、语料或pip缓存。
- 从官方HTTPS入口重新下载并校验SDK/core，在新prefix安装与编译native core。
- 从PyPI在全新venv中无缓存安装固定oracle依赖；真实语料重新下载并验hash。
- 最后对冻结源码执行 `tools/check.py --oracle --corpus`，任何失败均使整体失败。

共享的是同一宿主机的Linux内核、基础/usr和/etc，以及只读DNS文件与传输代理配置。
这不是另一台物理机器，也不是全新OS镜像；它单独验证不复用开发工具链与oracle依赖的安装。
首轮DNS符号链接目标缺失导致失败；第二轮下载校验后因归档可执行位未恢复而失败。
安装器按官方安装步骤恢复可执行权限，第三轮从全新prefix和下载重新开始，没有使用失败轮SDK。
隔离脚本的DNS挂载针对本次WSL布局；跨宿主复跑需检查该挂载，独立安装器本身不依赖WSL。

## 实际验收结果

第三轮于2026-11-05 23:05:14—23:11:14（UTC+8）完成，退出码0，整体PASS。
固定SDK/core从官方HTTPS重新下载；新安装的moon、moonc、moonrun身份吻合，native core构建通过。
PyPI向全新venv安装固定oracle，无pip缓存；三份NHANES文件重新下载并验hash。
随后冻结C16执行格式、检查、27组测试、构建、6项离线集成、两个oracle家族与真实数据全链路，
620,612单元格及声明元数据全部通过，实际最大ULP为0，没有跳过检查。

[独立安装证据](evidence/independent-install/README.md)保留完整stdout/stderr、运行结果、
安装回执、依赖版本、实际安装器/锁文件/验证脚本快照与SHA-256。两次失败分别保留。
已运行锁文件快照的archive_status仍写pending；它是当时的原样输入，结果由独立result.json证明。
当前tools/toolchain.json只更新该描述字段，其余锁定版本、URL入口规则与摘要和实测快照一致。

运行方式和前置依赖见[复现说明](reproduction.md)。后续应在目标远端runner验证同一入口；
本次没有创建远程、运行Actions或执行发布。
