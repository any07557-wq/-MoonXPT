# 冻结C16的全新安装验收

归档日期：2026-11-06。源码固定于
`1516dfd033d4ecee1bf0fd5cb35c9ec77762a774`，原16笔提交不变。

| 运行 | 结果 | 原始材料 |
|---|---|---|
| 2026-11-05 22:59（UTC+8） | FAIL：隔离环境的DNS符号链接目标未挂载 | [结果](fail-dns/result.json)、[完整日志](fail-dns/execution.log) |
| 2026-11-05 23:00—23:03（UTC+8） | FAIL：新下载SDK校验后缺可执行位 | [结果](fail-executable-mode/result.json)、[完整日志](fail-executable-mode/execution.log) |
| 2026-11-05 23:05—23:11（UTC+8） | PASS：全新下载、安装和完整检查，退出码0 | [结果](pass/result.json)、[完整日志](pass/execution.log)、[SDK回执](pass/sdk-install.json)、[新venv依赖](pass/oracle-packages.json) |

三轮各自使用新目录；通过轮没有复用前两轮的SDK或依赖。失败没有被改写成通过。
所有文件的SHA-256见[清单](manifest.json)，逐文件原路径及快照获取方式见[来源](provenance.json)。

## 已证明的内容

- bubblewrap隐藏整个开发HOME，前置检查确认旧SDK和pyreadstat/xport/pandas/numpy不可见。
- 测试源码仅由冻结C16的Git archive提取，不复制构建缓存、venv、SDK或语料。
- 官方SDK/core与官方原生包摘要重新下载，校验锁定hash；新prefix中版本检查和native core构建通过。
- PyPI全新venv、显式无pip缓存，固定oracle依赖重新安装，三份真实语料重新下载并验hash。
- 27组MoonBit测试、6项离线集成、ReadStat/xport验证、三份真实文件全链路通过。
  620,612单元格及已声明元数据完整比较，实际最大ULP为0；没有跳过请求的检查。

共享宿主Linux内核和基础/usr、/etc，使用宿主DNS及传输代理；这不是第二台机器、
全新OS镜像或远端CI。SDK安装器、oracle和产品源码均没有从开发目录取用现有安装。
本次隔离脚本的DNS挂载按WSL布局设置，跨宿主运行需检查该挂载。

## 输入与结果的对应

通过轮实际执行的[安装器与锁文件](pass/installer-tools/)在启动前复制并只读挂载。
[验证脚本](pass/verification-runner.py)快照的hash与运行开始时记录相同，
[verify.sh](pass/verify.sh)是实际执行的隔离内命令序列。
result.json分别登记日志、安装器、锁文件和验证脚本hash，清单再次校验全部归档文件。
快照中的archive_status在运行前写pending，原样保留；当前锁文件只更新该描述，固定值不变。

前两轮保留实际日志、结果及verify.sh。第二轮结束后恢复的工具快照单独放在
fail-executable-mode/recovered-tools，安装器及锁文件hash与该轮结果相符；第一轮未保留单独
runner快照，不用后来的版本替代。日志中的警告、时间和路径均未重写。

原[C15/C16源码重建证据](../README.md)继续保留，不能把它们与本次全新安装合并。
根因与官方来源见[安装报告](../../toolchain-installation.md)，重跑入口见[复现说明](../../reproduction.md)。
