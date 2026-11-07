# MoonXPT 0.1.0

模块：`any07557/moonxpt@0.1.0`。MoonBit原生SAS XPORT V5流式读写库，附native CLI，
支持CSV与版本化JSON元数据交换。运行不依赖Python、R或外部统计解析器。

这是供用户集成的库源码包。完整复现、tools、CI、验收证据及Git历史位于独立的
`moonxpt-0.1.0-source.zip`；也可查看[公开仓库](https://github.com/any07557-wq/-MoonXPT)。
本地制品生成不代表已经发布到Mooncakes或创建了GitHub Release。

## 构建与运行

已验证Linux x86_64 native，固定工具链为moon0.1.20261012/748b63c、
moonc v0.10.15+943464bfa，需要C编译器。安装器与依赖锁位于完整源码包的tools目录。

```sh
moon check --target native --deny-warn
moon test --target native --deny-warn
moon build --target native --release --deny-warn
./_build/native/release/build/cmd/moonxpt/moonxpt.exe --help
./_build/native/release/build/cmd/moonxpt/moonxpt.exe inspect tests/fixtures/readstat-v5.xpt \
  --json --count-rows --rows ORACLE=4
```

## 在独立工程中使用

将本包解压为library目录，与consumer目录并列，在父目录创建moon.work：

```toml
members = [ "library", "consumer" ]
```

consumer/moon.mod：

```text
name = "consumer/example"
preferred_target = "native"
import { "any07557/moonxpt@0.1.0" }
```

consumer/moon.pkg：

```text
import { "any07557/moonxpt" @xpt }
pkgtype(kind: "executable")
```

完整公共API示例见[逐行扫描](examples/scan/main.mbt)与[四成员写入](examples/write/main.mbt)，
接口签名见[核心](pkg.generated.mbti)、[交换层](exchange/pkg.generated.mbti)。
上述workspace方法无需registry发布；它不证明Mooncakes账号或命名空间已获确认。

## 0.1.0范围与兼容性

- XPORT V5，单/多成员，136/140描述符读取，140描述符写出，IBM数值与28种缺失。
- 保留字段原始字节，显式ASCII/Windows-1252；CSV为UTF-8，JSON schema_version=1。
- V5无行数，默认严格诊断尾部歧义；显式行数提示可保留歧义空白行，trim可能丢行。
- Double语义按SAS/ReadStat向零截断，低位可能丢失；CSV往返不保证原文件SHA-256。
- 默认不覆盖输出，进程内错误回滚；不承诺跨文件的机器崩溃原子性。

详细边界见[兼容矩阵](docs/compatibility.md)、[数值决策](docs/adr-002-numeric.md)和
[CSV/JSON契约](docs/exchange-format.md)。V8、其他后端、其他编码与外部值标签目录不在本版范围。

本包保留MoonBit测试和可再分发小夹具；完整源码包另外提供离线CLI集成及oracle/真实语料
验证脚本。本包不附SDK、oracle安装环境、原始NHANES数据、构建缓存或完整证据归档。

许可证：[MIT](LICENSE)。第三方来源与再分发边界见[THIRD_PARTY](THIRD_PARTY.md)、
[参考记录](docs/references.md)及licenses目录中的core LICENSE/NOTICE与工具链CREDITS。
