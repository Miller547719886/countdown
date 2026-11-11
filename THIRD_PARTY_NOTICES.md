# 第三方组件与数据说明

本项目新增的日历标注依赖以下 MIT 许可的上游项目。相关源码、版本记录、许可证文本和假期年度 JSON 随仓库保留；本项目不把这些上游内容重新声明为原创。

## Tyme4Swift

- 来源：[6tail/tyme4swift](https://github.com/6tail/tyme4swift)
- 固定版本：1.5.0，提交 `97f6ab433571a3fc7221f07b0857b71dd819316a`
- 用途：离线计算公历对应的二十四节气日期
- 位置：`Vendor/Tyme4Swift/`
- 许可：MIT，完整文本见 `Vendor/Tyme4Swift/LICENSE`

## holiday-cn

- 来源：[NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)
- 用途：中国大陆国务院公告对应的法定节假日、休息日和调休上班日
- 资源：`Sources/JiedianCore/Resources/Holidays/2007.json` 至 `2027.json`
- 每个年度文件保留上游的 `papers` 官方公告链接；资源许可文本见 `Sources/JiedianCore/Resources/ThirdParty/holiday-cn-LICENSE.txt`
- 当前资源只声明覆盖 2007—2027 年；没有资源的年份不会被程序推算成法定安排

年度数据仍以国务院最新公告为最终依据。更新资源时应固定上游提交并复核 `papers` 链接、`isOffDay` 字段和日期范围。
