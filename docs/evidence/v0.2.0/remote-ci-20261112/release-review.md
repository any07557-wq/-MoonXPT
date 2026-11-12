# v0.2.0 发布准备初审（2026-11-12）

本轮审查范围是远端 CI 证据归档及发布声明一致性，没有重新执行核心测试、重新生成正式
制品或进行新的独立代理代码审计。受验源码仍为
`b0d622d7f1e555b9c32cebf991682d9a7d25de0f`。

**证据可准备为独立本地提交；正式发布准备尚未完成。** 本次提交前审查时，本地 commit 和
后续 push 分别待用户明确授权，之前的授权不扩展到新增证据提交或发布。项目技术验收结论保持
`READY_WITH_SAS_VALIDATION_BLOCKED`。

## 已核对

- 本次候选提交仅包含 `docs/evidence/v0.2.0/remote-ci-20261112/` 和
  `docs/validation-report-v0.2.0.md`。上一轮对证据索引的追加已撤回；原索引与此前阶段材料
  保持原字节。用户原有 `docs/project-application.md` 不纳入。
- 原始日志和全部 artifacts 递归检查，包括两个外层 bundle、两个日志 ZIP、七个 artifact
  ZIP。凭据检查未发现未脱敏匹配；授权头出现处均为掩码。规则、范围、输入 hash 与扫描
  结果见 `scan_sensitive.py` / `sensitive-scan.json`。模式扫描不等于能识别所有未知秘密，
  未读取本机凭据文件或输出 token 值。
- 两个真实 run 的受验 commit、attempt=1、success 结论再次由只读 API 核对；4 类非 SAS
  job、81/81、620612 单元格、最大实测 0 ULP 与原始 receipts/logs 一致。下载 digest、内部
  清单、95 份源码身份、7 次新 SDK 安装均由离线入口复核；不把 skipped 算作 passed。
- 未发现 SAS 双向通过的虚假声明：`CHANGELOG.md`、`docs/boundary-v0.2.0.md`、兼容矩阵及
  最新验收报告均明确 blocked。S01–S14 没有实际 SAS 执行，其他 oracle 不替代 SAS。
- 行数推断/显式 hint、StrictSpec/NUL opt-in、完整成员链、多解、资源上限、非 seek 回放、
  legacy trim 有损语义、Writer 默认拒绝及显式 allow、失败处理等迁移边界均在
  `docs/boundary-v0.2.0.md` 中说明。模块和 CLI 开发横幅均为 0.2.0。
- v0.1.0 tag 对象及源码、远端 main 均与旧证据一致。只读比较 Release ID、正文、发布日期
  和七个附件的 ID/大小/API digest/创建更新时间均不变；详见 `review.json` 与原始 API
  `review-v010-release.json`。本次没有重新下载旧附件，不将元数据核对写成新的字节下载验收。

## 正式发布前待处理

1. **更新面向使用者的版本说明。** `README.library.md:7` 仍写“本次未 push 的开发分支”，
   已与现状不符。新 Release 正文及库入口说明还应直接披露 C05 blocked、四类非 SAS CI
   通过和行为收紧；引用历史文档时保留其日期，不把旧 not_run 状态当成当前结论。
2. **针对 0.2.0 整理并验证两类最终制品。** 当前证据证明开发分支源码和 CI，没有证明
   最终 0.2.0 源码包/库包已经冻结、重建和独立验收。历史 `tools/verify_artifacts.py:96`、
   `:107` 仍断言 27 组/0.1.0 横幅；`tools/test_consumer.py:16` 仍声明 0.1.0 依赖并使用本地
   workspace。保留历史验证入口；后续应新增适用 0.2.0 的制品与消费方验收，不能直接把
   v0.1.0 制品结果当作 v0.2.0 结果。该旧消费方 smoke 的通过也不证明 registry 发布成功。
3. **独立处理 Mooncakes 命名空间迁移。** 当前源码模块仍为 `any07557/moonxpt@0.2.0`，
   未来目标 `any07557-wq/moonxpt` 需另行迁移及消费方验收。GitHub 发布与 Mooncakes 权限、
   包名及是否已发布分别判断；本轮不自动改包名，不执行发布。

以上发布准备事项不否定已通过的非 SAS 核心/云端验收。SAS 阻塞本身保持公开披露，
不以静态程序或其他实现补记成功。本轮没有修改源码、workflow 或上述待修文件，没有创建
Tag/Release，也没有提交赛事。先把证据纳入 Git 历史，再针对最终发布候选及制品做完整审查。
