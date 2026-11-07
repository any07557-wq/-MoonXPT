# 阶段A：0.1.0版本一致性证据

2026-11-07，源码提交 `f1230b64e991ad94ba5455483665c6c4c387f77e`。
阶段A结果PASS：模块、CLI、当前README、示例依赖、候选包和待发布说明使用0.1.0。
目标标签名为v0.1.0，尚未创建。历史记录与工具链/SAS/schema版本未替换。

## 实际检查

- offline-check.log：格式、静态检查、27/27、构建及6项离线集成/公共消费方均通过。
  tools/test_inspect.py将实际CLI横幅与moon.mod比较。检查使用本机已安装的固定SDK，
  不计为独立安装或新的云端CI；没有重跑oracle/真实语料或benchmark。
- release-build.log与release-help.txt：根源码release构建通过，实际首行
  `MoonXPT 0.1.0 — SAS XPORT V5 (native)`。
- library/source-build.log、help.txt及inspect.json：两个候选包各自解压到新临时目录，
  release构建、0.1.0横幅与ORACLE=4小夹具inspect均通过，没有复制源码_build缓存。
- version-matrix.json：六类版本检查与阶段范围的汇总；version-report.json是候选检查器
  实际写出的结果，包含源码提交、ZIP摘要、包内模块版本与运行输出。
- library/source-inventory.json：包内每个文件的字节数与SHA-256。
- verify_packages.py：当时执行的检查脚本快照，固定上述源码提交；重跑需复制到新的输出
  目录，并从该Git提交执行，不能直接覆盖此证据目录。

根源码离线检查在提交前执行，CLI及测试文件随后按原内容提交；两个候选包均在提交后
生成。旧的_build/publish库ZIP保留，未被重命名后作为新包使用。

## 用于版本核对的候选包

候选ZIP本体保存在本地目录：
`.cache/version-unification/stage-a-1_yt_9pb/artifacts/`。
version-report.json的file路径相对于该run目录；本归档不嵌入ZIP，避免以后源码包递归
包含以前的源码包。以下文件不是正式Release制品，阶段B仍需完成最终制品验收。

| 候选包 | 文件数 | 字节数 | SHA-256 |
|---|---:|---:|---|
| moonxpt-0.1.0.zip | 236 | 352619 | 3246f3088218bc72698db642711c6e76012884eb7b74758a93d830cb83a8567f |
| moonxpt-0.1.0-source.zip | 268 | 425691 | 359d83499209e2edf75beb91327ac077dfde368cbd8c76e8575b82063ea2f467 |

两者根moon.mod、当前CLI源码、README、CHANGELOG和兼容性说明均为0.1.0。
source保留tools与.github，库包按当前过滤规则不含这两个目录。库包生成时仍有
repository字段缺失警告，保留在library-package.log；这是R3待办，不计为版本核对失败。

本目录文件完整性见manifest.json。CI Run42329267843的原始归档不变，不能被说成验证了
本次版本整理或此后提交。发布审查原文保持原样，当前处理状态见[版本说明](../../versioning.md)
及[审查处理表](../../release-review-2026-11-07.md)。没有push、触发CI、创建Tag/Release或发布Mooncakes。
