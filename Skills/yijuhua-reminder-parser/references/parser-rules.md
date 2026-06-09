# Parser Rules

## Dot Time

Treat `3.30`, `10.20`, `5.40`, and `6.18` as clock time only when preceded nearby by a period word such as `凌晨/早上/上午/中午/下午/晚上/今晚/明晚/明早`.

- `周三下午3.30约了旺脉` -> `15:30`, title `约了旺脉`
- `上午10.20开会` -> `10:20`
- `10.20约了旺脉` -> needs input, not a clear time

## Named Dates

Treat `618/6.18/双11/双十一/双12/双十二/5.20` and supported holidays as date anchors.

Supported connector words after a date alias: `号/日/那天/当天/这天`.

Supported after-date suffixes: `之后/以后/过后/后`.

- `6.18号给墨迹的电话` -> `6月18日 08:00`, title `给墨迹的电话`
- `6.18号之后下午6.18给墨迹的电话` -> `6月19日 18:18`, title `给墨迹的电话`
- `618那天上午6.18约下墨迹天气` -> `6月18日 06:18`

## Approximate Time Suffix

Remove approximate suffixes from the title when they belong to a parsed time expression: `左右/前后/上下/附近/多/来钟/出头`.

- `下午5点左右去前台拿快递` -> title `去前台拿快递`

## Regression Discipline

When adding a rule:

- Add a focused XCTest case.
- Add one NLP corpus line for durable coverage.
- Check `hasTimeExpression`, `hasMultipleTimeExpressions`, and `hasInvalidExplicitTimeExpression` for side effects.
