# 一句话提醒 iOS SwiftUI Skeleton

This folder contains the first SwiftUI source skeleton for the iOS MVP of 一句话提醒.

An initial Xcode project shell is available at:

```text
../YijuhuaTixing.xcodeproj
```

Open that project in Xcode to continue integration. If you prefer to create a fresh project manually, add these folders as source groups:

```text
App
Models
Services
ViewModels
Views
Utilities
Tests
Resources
```

## Minimum Target

Recommended:

```text
iOS 17+
SwiftUI
SwiftData
UserNotifications
```

The skeleton follows current Apple docs patterns:

1. `App` protocol for app entry.
2. `.modelContainer(for:)` for SwiftData integration.
3. `NavigationStack` for app navigation.
4. `Form` and `Section` for detail/settings screens.
5. `UNUserNotificationCenter` for local notification permission, scheduling, categories, and actions.

## Current Source Map

```text
App/
  YijuhuaTixingApp.swift
  AppDelegate.swift

Models/
  Reminder.swift
  RepeatRule.swift
  ReminderStatus.swift
  ParsedReminder.swift

Services/
  ReminderParser.swift
  ReminderStore.swift
  NotificationService.swift
  NotificationActionRouter.swift
  AnalyticsService.swift

ViewModels/
  TodayViewModel.swift
  ConfirmReminderViewModel.swift
  TaskDetailViewModel.swift

Views/
  Today/TodayView.swift
  Confirm/ConfirmReminderSheet.swift
  Confirm/NotificationPermissionSheet.swift
  Detail/TaskDetailView.swift
  Settings/SettingsView.swift
  Components/*

Tests/
  ReminderParserTests.swift
  RepeatRuleTests.swift
  ReminderStoreTests.swift
  NLPFixtureLoader.swift
  Resources/yijuhua-tixing-nlp-test-corpus-v0.1.jsonl

Tools/
  NLPCorpusSmokeTest.swift

Docs/
  DeviceNotificationTestChecklist.md
  TestFlightReadinessChecklist.md
  XcodeFirstRunChecklist.md

Xcode project:
  YijuhuaTixing app target
  YijuhuaTixingTests unit test target
  YijuhuaTixing shared scheme
```

## First Integration Steps

1. Open `../YijuhuaTixing.xcodeproj` in Xcode.
2. Select the `YijuhuaTixing` target.
3. Set your Development Team under Signing & Capabilities.
4. Run on a physical iPhone for notification testing.
5. Select the shared `YijuhuaTixing` scheme.
6. Run the `YijuhuaTixingTests` target from Xcode after a full Xcode/iPhone simulator SDK is active.

For the first device pass, follow `Docs/DeviceNotificationTestChecklist.md`.

For the TestFlight release gate, follow `Docs/TestFlightReadinessChecklist.md`.

For the first Xcode compile/run pass, follow `Docs/XcodeFirstRunChecklist.md`.

In Debug builds, Settings includes a `1分钟后测试通知` button. Use it to verify notification permission, scheduling, delivery, and SwiftData persistence without typing a reminder every time.

## NLP Regression Smoke Test

You can run the local parser corpus test without a full iOS simulator SDK:

```bash
cd /Users/mingjack/AI文件/Codex
env CLANG_MODULE_CACHE_PATH=/private/tmp/yijuhua-clang-module-cache \
swiftc \
  ios/YijuhuaTixing/Models/ParsedReminder.swift \
  ios/YijuhuaTixing/Models/RepeatRule.swift \
  ios/YijuhuaTixing/Utilities/ParserSettings.swift \
  ios/YijuhuaTixing/Services/ReminderParser.swift \
  ios/YijuhuaTixing/Tools/NLPCorpusSmokeTest.swift \
  -o /private/tmp/yijuhua_nlp_smoke
/private/tmp/yijuhua_nlp_smoke yijuhua-tixing-nlp-test-corpus-v0.1.jsonl
```

Current baseline:

```text
Passed: 208/208
clear_datetime: 40/40
relative_time: 31/31
fuzzy_period: 38/38
weekday_monthday: 30/30
repeat: 31/31
needs_input_unsupported: 18/18
edge_conflict_overdue: 18/18
title_pattern: 2/2
```

With full Xcode installed and selected, the matching XCTest entry point is:

```bash
xcodebuild test -project ios/YijuhuaTixing.xcodeproj -scheme YijuhuaTixing -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Important Notes

The notification action router persists complete/snooze actions in `UserDefaults` until `TodayView` registers SwiftData handlers. This keeps notification actions available during a cold launch path, then flushes them once the main view is ready.

Notification scheduling uses repeating `UNCalendarNotificationTrigger`s for daily, weekly, and monthly reminders. Weekday reminders are scheduled as five repeating notification requests from Monday to Friday. Hourly interval reminders use `UNTimeIntervalNotificationTrigger`. Snoozed repeating reminders use one-time triggers so a temporary delay does not become the new permanent repeat time.

`LocalReminderParser` is the first production candidate for rule-based parsing. Keep the 200-line JSONL corpus green before changing parser behavior.

The MVP should keep this order:

1. Make local reminders persist.
2. Make notifications reliable.
3. Make complete/delete/snooze consistent.
4. Improve NLP coverage.
5. Ship TestFlight to seed users.
