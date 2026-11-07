# 正式v0.1.0标签完整CI

[GitHub Run42361761773](https://github.com/any07557-wq/-MoonXPT/actions/runs/42361761773)，
attempt1，workflow_dispatch，ref=v0.1.0，real_corpus=true。
被测源码严格为 `2cddd31bb8b88648f619969dbb4fe195051735b4`，与两类最终制品相同。
offline和public-corpus均success；不是将main push中条件跳过的语料job算作通过。

归档包含run/jobs/artifacts原API、两个原artifact ZIP及其全部解压文件、原workflow日志ZIP
与解压日志、下载摘要、工作流快照和本地完整性核验结果。GitHub原ZIP摘要与包内manifest、
安装器/锁文件、源码archive摘要及Actions上下文均核对；27/27、6项离线入口、独立oracle、
620612单元格/声明元数据完整通过，最大ULP0。

三份真实NHANES均为数值列；字符、CP1252、多成员和特殊缺失由独立小夹具/向量覆盖。
没有运行云端benchmark；人工指定的第二台SSH机器未另测。SDK/oracle/语料均是job内新安装/下载。

manifest.json登记本目录全部文件（自身除外）。只读重新核验：

```sh
python3 tools/verify_ci_evidence.py docs/evidence/github-actions/run-42361761773
```

核验脚本读取已存证据和Git对象，不触发新的工作流或产品测试。
发布本身及附件回下载另外见[阶段C记录](../../release-20261107/README.md)。
