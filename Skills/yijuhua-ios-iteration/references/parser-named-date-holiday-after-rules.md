# Parser Named Date Holiday After Rules

Use this reference when changing natural language parsing for named dates such as festivals, shopping events, and holiday phrases.

## Core Product Rule

`节假日之后` means the first day after the whole holiday period, not simply the day after the festival anchor.

Example:

- `端午节之后回访客户` -> `2026-06-22 08:00`
- Reason: 2026 Dragon Boat holiday is treated as `2026-06-19...2026-06-21`, so "after Dragon Boat" is `2026-06-22`.

## Phrase Coverage

Treat these as after markers:

- `之后`
- `以后`
- `过后`
- `后`
- `结束之后`
- `活动结束后`
- `假期结束后`
- `过完端午`

Title cleanup should remove the full date phrase and keep only the task content.

## Default Time

- Named date after phrases without explicit time use the morning default, currently `08:00`.
- Explicit `结束后` phrases use `10:00` when no time is provided, because users often mean after the event or holiday has actually ended.

Examples:

- `端午节之后一起吃个饭` -> `2026-06-22 08:00`
- `端午假期结束后回访客户` -> `2026-06-22 10:00`
- `618结束之后庆祝一下` -> `2026-06-19 10:00`

## Holiday After Kinds

Named date rules should not all use a flat `+1 day`.

- Shopping or single-day events: `618之后`, `双十一之后`, `双十二之后` -> next day.
- Short public holidays: `元旦`, `清明`, `端午` -> first day after the inferred short holiday period.
- Spring Festival: after the Spring Festival holiday period.
- Labor Day: after the May Day holiday period.
- National Day: after the National Day holiday period.
- Mid-Autumn: after the short Mid-Autumn period, or after the combined National Day period when it overlaps October 1-8.

The current local heuristic mirrors Android:

- Short public holiday anchor on Thursday, Friday, or Saturday -> `+3 days`.
- Short public holiday anchor on Sunday -> `+2 days`.
- Otherwise -> `+1 day`.
- National Day normally -> October 8.
- National Day with Mid-Autumn overlap inside October 1-8 -> October 9.
- Mid-Autumn inside October 1-8 -> October 9.

## Regression Requirements

Every supported real phrase must be covered in:

- `YijuhuaTixing/Tests/ReminderParserTests.swift`
- `YijuhuaTixing/Tests/Resources/yijuhua-tixing-nlp-test-corpus-v0.1.jsonl`

Important examples:

- `618结束之后庆祝一下` -> `2026-06-19 10:00`
- `618活动结束后庆祝一下` -> `2026-06-19 10:00`
- `端午节之后回访客户` -> `2026-06-22 08:00`
- `端午节之后一起吃个饭` -> `2026-06-22 08:00`
- `端午假期结束后回访客户` -> `2026-06-22 10:00`
- `过完端午回访客户` -> `2026-06-22 08:00`
- `中秋节之后寄礼盒` -> `2026-09-28 08:00`
- `元旦之后做年度计划` -> `2027-01-04 08:00`

## Limit

This is a deterministic local heuristic, not an official yearly holiday calendar. If the product needs exact holiday arrangements for every year and adjusted working days, add a yearly holiday table instead of stretching regex rules.
