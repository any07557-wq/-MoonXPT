# Mooncakes发布准备

2026-11-07，状态：**准备完成，尚未发布**。GitHub Release与registry发布独立处理。
用户已确认后续使用 `any07557-wq` 命名空间，目标模块 `any07557-wq/moonxpt@0.1.0`；
`moon whoami`的实际登录名为any07557-wq。没有读取或归档登录凭据。

已发布GitHub v0.1.0的标签和ZIP继续使用 `any07557/moonxpt`，源码提交固定2cddd31。
本轮不修改该标签、ZIP或main上的模块名；两种名称不被视为同一个registry包。

## 可审查预备结果

从阶段B实际库ZIP派生了新命名空间候选，移除旧ARTIFACT/PACKAGE-MANIFEST，
同步模块名、import、接口签名与库README。原夹具字节不变；旧manifest不冒充新内容证明。

- 本地预备包：`.cache/release-stage-c/mooncakes-preparation/any07557-wq-moonxpt-0.1.0-UNPUBLISHED.zip`。
- SHA-256：`5286e6ac34c36cb829a2247e75e7bd9818c8158ff939359e9430aa8c1b0875eb`。
- 静态检查、27/27、native release构建、仅依赖该候选的公共API消费方全部通过。
- [补丁、回执及原日志](evidence/release-20261107/mooncakes/)仅覆盖库包所含文件；
  不是完整仓库迁移提交。该检查复用固定本地SDK，不冒称新安装或云端CI。
- `moon view`对旧包与新目标0.1.0的查询当时均返回HTTP404；这只记录当时的查询结果，
  不能证明命名空间权限、未来版本可用或registry安装成功。

该预备包未上传到GitHub正式附件，也未提交Mooncakes。后续最终制品须从新的已提交源码
生成，重新登记清单/摘要；不能直接用当前派生ZIP替换GitHub v0.1.0。

## 实际发布前仍需完成

1. 新建追加提交，统一完整仓库的模块、imports、生成接口、消费方工具、文档和打包策略。
   历史证据、失败日志、旧标签及旧制品身份保留原样。
2. 从该确定提交重新生成完整源码与库包，验证格式、构建、测试、公共消费方、包过滤和
   许可证，并保存最终摘要及对应CI；当前库范围补丁不能覆盖这些工作。
3. 重新确认登录账号、命名空间发布权限和目标版本占用；只读lookup与workspace消费
   不能替代registry权限或下载验证。
4. 取得单独发布授权后执行registry发布，再从独立消费工程验证真实registry安装。

官方流程见[MoonBit包管理文档](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html)。
本轮未执行`moon publish`，没有将GitHub Release成功记作Mooncakes成功。
