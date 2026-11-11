# 中国法定节假日与二十四节气数据源调研

日期：2026-11-11

## 结论（给 Swift/macOS 应用）

首选直接 vendoring **[NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)** 的按年 JSON（保留其 `papers` 来源链接和 MIT 许可证声明）。它专注国务院发布的法定节假日/调休数据，JSON 结构很小，适合在 Swift 中用 `Codable` 解码；仓库有 CI 自动抓取、变更发布和可复核的国务院文件链接。二十四节气不在该仓库范围内，建议同时 vendoring **[wolfhong/LunarCalendar](https://github.com/wolfhong/LunarCalendar)** 的节气常量/算法，或仅采用其 MIT 数据作为独立模块。

如果希望一个文件同时覆盖节假日、调休、工作日、农历和节气，可评估 **[vsme/chinese-days](https://github.com/vsme/chinese-days)**；它更完整，但生成/发布链路较复杂（TypeScript 构建产物），Swift 项目应固定版本并把生成后的 JSON 作为应用资源，而不是运行时依赖 CDN。

## 候选对比

| 项目 | 覆盖与格式 | 更新策略/新鲜度 | 许可证与集成判断 |
| --- | --- | --- | --- |
| [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn) | 法定节假日、调休/补班；每年一个 JSON（也有 ICS）；字段为 `year`、国务院文件 URL 数组 `papers`、`days[{name,date,isOffDay}]`。仓库 README 标注 JSON Schema。 | README 声明 CI 自动更新；当前含 2024、2025、2026 年文件。每个年份 JSON 都把官方 gov.cn 通知放入 `papers`，例如 [2026.json](https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/2026.json) 引用 [国务院 2026 安排](https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm)。 | MIT（[LICENSE](https://github.com/NateScarlet/holiday-cn/blob/master/LICENSE)）。最适合作为“法定安排”主数据；需随应用附带 MIT 文本和版权声明。 |
| [vsme/chinese-days](https://github.com/vsme/chinese-days) | 同时提供节假日、调休日、工作日、24 节气、农历转换；构建出总 JSON、按年 JSON 和 ICS。README 明确节假日 2004–2026（含 2020 春节延长），节气/农历 1900–2100；按年文件可直接取 [2025.json](https://cdn.jsdelivr.net/npm/chinese-days/dist/years/2025.json)。 | README 描述每日 GitHub Action 检查下一年国务院公告，自动提取/校验并开 PR；只新增最大年份的下一年，正式 PR 合并后自动 patch 发布。2026-11-05 左右仍有推送，维护活跃。 | MIT（[LICENSE](https://github.com/vsme/chinese-days/blob/main/LICENSE)）。覆盖最全，但应锁定 npm/Git commit，审核生成数据后再 vendoring；不要把 jsDelivr 作为离线应用运行时依赖。 |
| [wolfhong/LunarCalendar](https://github.com/wolfhong/LunarCalendar) | 农历/公历转换、二十四节气和若干中式节日；README 项目描述范围 1900–2100，算法/常量可单独移植。不是国务院调休日历。 | 最近代码推送为 2024-05-22；没有官方公告抓取或按年调休更新策略。适合作为稳定的节气算法基线，不适合做当前法定节假日源。 | MIT（[LICENSE](https://github.com/wolfhong/LunarCalendar/blob/master/LICENSE)）。可与 holiday-cn 分开 vendoring，减少把 Python 运行时带入 Swift。 |
| [dark-wind/statutory-holidays-cn](https://github.com/dark-wind/statutory-holidays-cn) | 中国法定节假日数据，Apache-2.0；格式/实现偏库代码，README 与数据主要是早期年份。 | 仓库最后推送约 2019，元数据更新约 2020；没有持续抓取安排，不能覆盖近年国务院调休变化。 | Apache-2.0 兼容 vendoring，但数据明显过时，仅可作历史交叉校验。 |
| [lanceliao/china-holiday-calender](https://github.com/lanceliao/china-holiday-calender) | README 描述 2023–2025 节假日、调休，提供 ICS/API。 | 仓库很活跃，但 GitHub API 的 `license` 字段为空，项目未提供可确认的标准开源许可证。 | 不建议直接 vendoring：缺少明确许可证；只能作为外部参考或在取得作者授权后使用。 |

## 数据格式映射建议

对 `holiday-cn` JSON 建议定义：

```swift
struct HolidayYear: Decodable {
    let year: Int
    let papers: [URL]
    let days: [HolidayDay]
}

struct HolidayDay: Decodable {
    let name: String
    let date: String       // ISO-8601 yyyy-MM-dd，按本地日历解析
    let isOffDay: Bool     // false 表示调休上班日/补班日
}
```

不要把 `isOffDay == true` 等同于“法定节日当天”：仓库 README 明确周末连休的部分日期不一定是法定节日；产品若要区分“法定假日、休息日、补班日”，应在本地模型中保留来源和日期类型，或额外读取 vsme 的工作日字段。

## 维护与发布建议

1. 在构建时固定上游 commit/tag，下载所需年份 JSON 到项目资源目录；运行时离线读取，避免 GitHub/jsDelivr 可用性和内容漂移。
2. 每年国务院新公告发布后更新资源，检查 `papers` URL、`days` 中 `isOffDay=false` 的补班日期，并保留上游版本号/commit 作为审计信息。
3. 对节气，采用 1900–2100 范围内的固定表/算法，并用 `Calendar(identifier: .chinese)` 或独立测试向已知日期做回归；不要从法定节假日 JSON 推导节气。
4. 在应用的第三方声明中分别保留 NateScarlet、vsme、wolfhong 的 MIT 文本（若实际 vendoring 对应代码/数据）；若仅复制事实性日期数据，仍建议保留来源、许可证和原始 URL 以便追溯。

## 官方依据

- [国务院《全国年节及纪念日放假办法》（2024 修订）](https://www.gov.cn/zhengce/content/202411/content_6986380.htm)：法定节假日类别和放假规则。
- [国务院办公厅关于 2026 年部分节假日安排的通知](https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm)：2026 年具体放假、调休和补班日期；`holiday-cn/2026.json` 的 `papers` 字段直接引用该文件。

以上官方通知是最终权威；开源仓库属于机器可读整理，应用发布前应检查其年份文件是否已经跟随最新通知更新。
