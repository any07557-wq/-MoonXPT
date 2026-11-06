# 官方工具链来源调查证据

每个UTC时间目录保存一次独立探测的 `sources.json`，包含URL、状态、受控响应头、
读取字节数与body摘要。403、TLS失败、GitHub API限流均保留为各自结果。
不将一次失败请求关联到前一次成功缓存的body。

保留小型错误XML和官方checksum文本。第三方整页HTML、整份README、归档二进制前缀
和完整tag列表不纳入Git；其摘要与保留情况见 body-retention.json。
原始HTTP报告的body_file字段仍是当时缓存文件名，未保留者按该清单解释。
最终选定版本、官方来源及候选Wasm地址见 selected-release.json。

初次探测早于按运行目录保存的实现；initial-readonly-responses中只保存当时尚存的
小型body，没有伪造未保留的整份HTTP报告。后续运行均有独立报告。

原错误路径使用moon构建工具版本，修正为moonc编译器版本后原生归档206、官方摘要200。
这组对照用于确定安装器版本键错误；SDK安装和项目测试是否通过另见隔离运行证据，
不能单凭HTTP响应宣布验收成功。
