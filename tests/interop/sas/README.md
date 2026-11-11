# 真实SAS XPORT Engine验收准备

**当前状态blocked**：用户2026-11-11确认没有可合法使用的SAS环境或runner。
以下程序尚未在SAS编译/执行，不能视为通过；不使用mock、CPORT或其他oracle冒充。

所需环境：Linux x86_64的合法SAS Foundation许可、可执行绝对路径、实际可用的XPORT
Engine、独立空目录、C编译器及固定MoonBit SDK。由操作者确认许可及session encoding。

1. 构建MoonXPT和tests/interop/driver，创建新工作目录及ref/、imported/、moon/。
2. 用interop driver生成moon/内6个单成员及一个多成员XPT，明确producer为MoonXPT，
   不得把这些文件标为SAS生成。SHORT含已知风险，明确allow并保留实际行数。
3. 设置MOONXPT_SAS_WORK，真实执行create_inputs.sas，保存版本、平台、完整LOG/listing。
   检查XPORT Engine输出的sas_single.xpt与sas_multi.xpt及SHA-256；保留原始字节。
4. 用MoonXPT inspect/export读取SAS输入，逐成员提示TEST_A=3、TEST_B=2、EMPTY=0、
   SHORT=2、FULLBL=1、TAGS=28。比较行数、全部逐行值、变量顺序、存储宽度、标签、
   format/informat；不得只检查首成员或只看进程退出码。
5. 真实执行read_moonxpt.sas，保存PROC CONTENTS、PROC COMPARE及各SYSINFO。
   任何差异保留，不自动放宽容差或跳过SHORT。若引擎确实丢短空白末行，按实际LOG及
   行数记录限制，不能把预期模板当作已证明的SAS行为。
6. 将程序/LOG/listing、SAS版本、环境说明、双方XPT hash、MoonXPT CSV/JSON及比较结果
   打包归档到新的docs/evidence/v0.2.0/sas-实际日期目录。

特殊缺失仅在实际SAS接口保留tag时判定S12；PROC COMPARE的实际比较范围也要核对。
非ASCII S13需在目标SAS session encoding确认后增加独立样例，当前模板仅覆盖ASCII；
不能将CP1252的其他oracle结果扩大为SAS已验证。所有S01–S14当前均blocked。

`tools/run_sas_v020.py`是手动执行入口，必须提供真实可执行路径和授权确认参数。
该入口拒绝覆盖已有工作目录，检测LOG错误和比较标记；它仍不能代替真实环境验证。
