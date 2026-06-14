---
name: yijuhua-reminder-parser
description: Use when modifying or reviewing YijuhuaTixing Chinese reminder parsing, especially date/time extraction, repeat rules such as daily/hourly/weekly/biweekly/monthly/weekdays, dot-separated time, festival dates, after-date wording, approximate time suffixes, title cleanup, and parser regression tests.
metadata:
  short-description: Maintain Yijuhua reminder parsing rules
---

# Yijuhua Reminder Parser

Use this skill when changing `LocalReminderParser` or interpreting user reports about wrong reminder date, time, or title extraction.

## Workflow

1. Reproduce the phrase as a parser example first.
2. Decide each span role: date anchor, clock time, repeat rule, or title.
3. Prefer small local rules over broad regex cleanup.
4. Update XCTest and the NLP corpus for every new ambiguity.
5. Validate with a pure parser check when simulator tests are unstable; still run `xcodebuild build-for-testing`.

## Rule Priorities

- Explicit clock time beats fuzzy period words.
- Date anchors beat dot-time unless the dot number has nearby time-period words.
- Date suffix `之后/以后/过后/后` means use the configured after-date offset.
- Repeat expressions must set `ParsedReminder.repeatRule`; do not leave them as title text.
- Title cleanup must remove the entire parsed date/time phrase.
- Do not fix title cleanup by deleting arbitrary leftover words globally.

## Key Files

- `YijuhuaTixing/Services/ReminderParser.swift`
- `YijuhuaTixing/Tests/ReminderParserTests.swift`
- `YijuhuaTixing/Tests/Resources/yijuhua-tixing-nlp-test-corpus-v0.1.jsonl`

For concrete edge cases, read `references/parser-rules.md`.
