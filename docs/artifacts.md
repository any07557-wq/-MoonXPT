# 0.1.0两类最终制品

阶段B生成本地可交付制品，不执行push、创建Tag/Release、发布Mooncakes或提交赛事。
两类ZIP必须来自同一个已提交Git对象；源码提交、tree、文件清单与SHA-256随制品登记。
每次使用新的输出目录，不覆盖阶段A候选包或任何历史证据。

阶段B已完成：[最终制品验收记录](evidence/artifacts-20261107/README.md)。保留制品位于
dist/0.1.0/stage-b/，两包均绑定提交2cddd31bb8b88648f619969dbb4fe195051735b4。

| 制品 | 内容与用途 |
|---|---|
| moonxpt-0.1.0-source.zip | 全部已提交源码、tools、CI、测试、文档、许可证及原验收证据；另附history/moonxpt.bundle保存截至所选提交的完整历史 |
| moonxpt-0.1.0.zip | 经moon package与.moonignore过滤的库源码，专用README.library.md、接口、CLI/示例、测试夹具、用户契约文档、许可证及第三方记录 |

完整源码ZIP不是过滤库包的另一个名称。Git archive本身没有提交历史，因此本流程另外
生成完整Git bundle，并在全新目录克隆验证HEAD、提交数和源码内容。bundle只含提交对象
和必要refs，不含原仓库的凭据、hooks、配置或未跟踪缓存。历史范围以ARTIFACT.json的
source_commit为止；之后追加的验证文档提交不在该源码制品中。

## 生成

先提交此次打包所需的源码和策略，然后从仓库根目录运行：

```sh
python3 tools/build_artifacts.py --commit HEAD --output dist/0.1.0/selected-commit
```

输出目录必须不存在。生成器读取Git对象而非工作区改动，源码包保留全部已跟踪文件；
库包由相同源码调用moon package生成，并核对每个文件与Git字节一致，检查可点击的
本地文档链接。模块readme字段指定README.library.md，避免库包说明指向已过滤的tools。

两包各附ARTIFACT.json和PACKAGE-MANIFEST.json，前者标明用途、版本及源码身份，
后者登记包内每个文件的大小/摘要（不登记manifest自身）。ZIP外另有release-manifest.json、
两份全量inventory及SHA256SUMS。源码包中的history目录与两份包元数据是生成的补充文件，
不冒称它们原本属于Git tree。

两类制品排除.git工作目录、_build、.cache、dist、虚拟环境、下载SDK和真实NHANES数据。
源码包会保留Git内的原始失败/CI证据及其中的小型原ZIP，它们是审查材料而非构建缓存。
库包去掉tools、CI、开发文档和完整证据，只保留指定的用户契约和参考记录。

## 许可证与第三方核对

生成和验证均检查LICENSE、THIRD_PARTY.md、MoonBit core LICENSE/NOTICE、工具链CREDITS
及小夹具来源清单与选定Git提交逐字节一致，并核对所有小夹具的固定SHA-256。
SDK、oracle wheel和原始调查数据不随包分发。本检查确认声明与文件保留情况，不把
第三方资料重新授权为MIT，也不宣称所有工具链组件都链接进产品。

## 从实际ZIP验证

```sh
python3 tools/verify_artifacts.py dist/0.1.0/selected-commit \
  --evidence-dir .cache/artifact-verification/new-run
```

验证器先核对ZIP与包内manifest、许可证和夹具，再进入bubblewrap隔离用户空间：
开发HOME隐藏，PATH最初仅含系统工具；新SDK/core从官方固定入口下载并校验，
新venv从PyPI无缓存安装固定oracle，真实语料重新下载验hash。
源码包执行27组、离线集成、两个oracle家族及三份真实文件完整对照；库包另行执行
静态检查、27组、release构建、CLI inspect/export/write与独立公共API消费方。
消费方只指向解压库目录，开发仓库不可见；辅助检查脚本来自完整源码包，不进入产品依赖。

系统需Linux x86_64、bubblewrap用户命名空间、Git、C编译器、Python3.14.4及venv，
能访问官方SDK/PyPI/CDC。隔离共享宿主基础OS、Linux内核和网络/DNS/代理，不是新云端run。
SDK是本轮新安装，供这两个独立解压树使用；没有复用开发SDK、venv或源码构建缓存。
失败退出非零并保留日志与结果，不将历史云端通过替代此轮制品验证。

发布身份与最终制品分开：repository字段填写实际公开仓库，Mooncakes账号/命名空间及
版本占用仍需发布前确认。SHA256SUMS与本地验证通过不表示已创建v0.1.0标签或Release。

实测同一提交再次打包时，库ZIP字节一致，但Git bundle的重新压缩导致源码ZIP字节不同；
恢复的Git历史及源码内容一致。检查保留的具体制品时以其SHA256SUMS为准，不将源码身份
一致扩大成压缩字节完全确定的承诺，详情及两次摘要保留在验收记录中。
