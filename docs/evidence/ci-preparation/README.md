# 外部验收准备与本地CI入口检查

归档日期：2026-11-06。被测准备提交为
`958f9fce15feeea0ee39f541faafad831af3db38`，P0冻结基线仍为
`1516dfd033d4ecee1bf0fd5cb35c9ec77762a774`。

本目录记录的是本地检查和预演，不是第二台机器或远端Actions运行。
用户确认二者均尚未配置，未创建远程、push、发布或执行外部任务。

## 静态检查与移交材料

- local-checks.json / local-checks.log：actionlint、Python语法、stdout/stderr与非零退出码保留、
  未提交验证脚本拒绝执行、已有证据目录不覆盖。
- official-inputs.json：已核对的Action发布commit、Python 3.14.4分发元数据，以及校验过的
  官方actionlint 1.7.12归档摘要。第三方可执行文件没有纳入Git。
- workflow.yml：本次实际检查的CI配置快照；hash与local-checks.json一致。
- bundle-receipt.json / bundle-validation.json：包含完整19笔历史的本地传输bundle，已验证
  可以克隆、HEAD准确且没有构建或依赖缓存。bundle本体留在本地.cache/ci-preparation/，
  不作为正式Release源码zip，也不在证据目录中重复嵌入Git历史。
- uncommitted-runner-guard/：在准备提交之前运行的预期拒绝用例，result=FAIL是预期结果，
  证明验证脚本与已提交源码版本不一致时在下载前退出。

每次运行的目录、日志、回执均原样保留，SHA-256见manifest.json。
compiler.log保留编译器原始输出的末尾空行；归档时没有为格式检查重写日志。
完整第二台机器步骤与远端验收要求见[外部验收说明](../../external-verification.md)。

## 本地预演

offline-rehearsal/与full-rehearsal/分别使用全新临时目录和SDK下载，没有共享开发SDK。
主机为Ubuntu 26.04；计划的远端runner为Ubuntu 24.04，不能推断后者通过。
两类运行中的github_actions均为空；只有取得实际run URL与artifact后才能登记远端结果。

| 运行 | 实际结果 | 证据 |
|---|---|---|
| offline本地预演 | FAIL：官方SDK归档下载超过600秒上限 | [结果](offline-rehearsal/result.json)、[下载日志](offline-rehearsal/install-sdk.log)、[失败记录](offline-rehearsal/failure.log) |
| full本地预演 | FAIL：官方SDK归档下载超过600秒上限 | [结果](full-rehearsal/result.json)、[下载日志](full-rehearsal/install-sdk.log)、[失败记录](full-rehearsal/failure.log) |

两类预演均在官方原生包传输阶段超时，未取得完整SDK、未运行新的构建或测试，未安装
oracle或下载语料。保持非零退出码与FAIL，没有把静态检查通过或原开发环境的结果替代它们。
这证明失败回执路径实际工作；它不证明该CI入口完整执行成功。
此前[C16独立安装完整通过](../independent-install/README.md)的历史证据继续单独保留。

安装器时间上限保持600秒，已有SDK未用于这两次预演。
后续在配置好的实际独立主机/远端runner重跑，按新的证据目录保留每次结果。
