# Parser Dot Number Rules

Dot-separated numbers are ambiguous in Chinese reminder input. Always decide their role from nearby context before changing parser behavior.

## Role Priority

1. Dot month-day with suffix.
2. Dot clock time with a date anchor or time-period word.
3. Ambiguous dot number with no context.

## Dot Month-Day

Treat `10.30号` and similar expressions as calendar dates when followed by:

- `号`
- `日`
- `那天`
- `当天`
- `这天`

Example:

- `10.30号给中青打电话` -> `10月30日 08:00`, title `给中青打电话`

Implementation notes:

- Parse as month/day before generic `数字 + 号` day extraction.
- Remove the whole date phrase from title, not only the trailing `30号`.

## Dot Clock Time

Treat `10.30` as clock time only when nearby context provides a date or time anchor.

Time-period anchors:

- `凌晨`
- `早上`
- `上午`
- `中午`
- `下午`
- `晚上`
- `今晚`
- `明晚`
- `明早`

Date anchors:

- `明天`
- `后天`
- `下周一`
- `周三`
- `6.18号`
- Other supported absolute day expressions.

Examples:

- `明天10.30给中青打电话` -> tomorrow `10:30`, title `给中青打电话`
- `周三下午3.30约了旺脉` -> Wednesday `15:30`, title `约了旺脉`

Only remove the dot time from title when it was actually accepted as a time expression.

## Ambiguous Dot Number

Do not guess when there is no date anchor or time-period word.

Example:

- `10.20约了旺脉` -> needs input, title `10.20约了旺脉`

## Regression Requirements

Every real user-reported phrase must be added to:

- `YijuhuaTixing/Tests/ReminderParserTests.swift`
- `YijuhuaTixing/Tests/Resources/yijuhua-tixing-nlp-test-corpus-v0.1.jsonl`
- `Skills/yijuhua-reminder-parser/references/parser-rules.md` or this reference file.

Keep paired tests for both sides of the ambiguity:

- A positive case that should parse.
- A negative case that should remain ambiguous.
