# Task Time Grouping

Use this reference before changing pending task archive buckets or completed history buckets.

## Pending Tasks

Group unfinished, undeleted reminders by reminder time. A reminder must appear in exactly one bucket, using nearest task date first.

Order:

1. 已过时间
2. 当天任务
3. 本周内任务
4. 下周内任务
5. 本月内任务
6. 下月内任务
7. 本季度内任务
8. 半年内任务
9. 本年内任务
10. 明年内任务
11. 后年内任务
12. 四年内任务
13. 五年内任务
14. 五年后

Rules:

- Weeks start on Monday and may cross natural years.
- Month, quarter, half-year, and year buckets use natural calendar boundaries.
- Natural quarters are Jan-Mar, Apr-Jun, Jul-Sep, and Oct-Dec.
- Natural half-years are Jan-Jun and Jul-Dec.
- Year buckets are relative to the current natural year: current year, +1, +2, +3, +4, then later.
- Cross-year dates still enter near buckets first when applicable.

Examples with today as `2026-12-28`:

- `2026-12-31` -> 本周内任务
- `2027-01-03` -> 本周内任务
- `2027-01-05` -> 下周内任务
- `2027-01-11` -> 下月内任务
- `2027-01-31` -> 下月内任务
- `2027-02-01` -> 明年内任务

## Completed History

Group completed records by `completedAt`, not by original reminder time. Deleted history currently remains sorted by delete/update time and is not grouped by these headers.

Order:

1. 当天内已完成任务
2. 本周内已完成任务
3. 本月内已完成任务
4. 本季度内已完成任务
5. 半年内已完成任务
6. 今年内已完成任务
7. 去年内已完成任务
8. 前年内已完成任务
9. 五年内已完成任务

Rules:

- Use nearest past bucket first.
- Future completed timestamps should not appear.
- Five-year history is display scope, not physical cleanup.

## Validation

Run the focused tests after changes:

```bash
xcodebuild test-without-building \
  -project YijuhuaTixing.xcodeproj \
  -scheme YijuhuaTixing \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:YijuhuaTixingTests/ReminderArchivePeriodTests \
  -only-testing:YijuhuaTixingTests/ReminderHistoryPeriodTests
```

If simulator execution is unavailable, run `xcodebuild build-for-testing` and at least verify deterministic calendar examples with unit-test-equivalent checks.
