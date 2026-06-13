---
name: yijuhua-ios-iteration
description: Use when planning, implementing, or reviewing YijuhuaTixing iOS product iterations, especially App Store-safe feature scope, reminder detail flows, external map navigation, SwiftData migrations, generated Info.plist settings, parser regression handling, wheel time picker hit-area issues, and focused validation.
metadata:
  short-description: Ship Yijuhua iOS iterations safely
---

# Yijuhua iOS Iteration

Use this skill when turning a user-reported product issue or small feature idea into a scoped iOS change for `YijuhuaTixing`.

## Working Rule

Keep the current reminder creation flow stable. New capabilities should sit beside the core "one sentence -> time -> reminder" path unless the user explicitly asks to redesign that path.

## Workflow

1. Clarify the intended user behavior in one concrete example.
2. Pick the smallest App Store-safe implementation.
3. Check persistence, view model state, UI affordance, failure handling, and tests.
4. Avoid new permissions, SDKs, accounts, or server dependencies unless the feature truly needs them.
5. Validate with the narrowest relevant XCTest or `xcodebuild build-for-testing`.
6. Record real user examples in tests, corpus files, and references so future changes do not regress them.

## Scope Principles

- Prefer system APIs and URL schemes over third-party SDKs for simple handoff features.
- Do not request location permission for address notes or external navigation handoff.
- Keep optional fields optional: trim input, save empty strings as `nil`, and avoid blocking reminder creation.
- If a detail page adds editable data, make the save state obvious: enabled button, saving state, success feedback, and rollback on failed persistence or notification scheduling.
- If a parser bug is reported, decide whether each span is a date anchor, clock time, repeat rule, address, or title before changing regexes.
- If a wheel time picker causes scroll-view mis-touch, make the visual selected capsule match the real interactive hit area; do not rely on SwiftUI `.clipped()` alone.

## Key Files

- `YijuhuaTixing/Services/ReminderParser.swift`
- `YijuhuaTixing/Services/ReminderStore.swift`
- `YijuhuaTixing/Services/MapNavigationService.swift`
- `YijuhuaTixing/Models/Reminder.swift`
- `YijuhuaTixing/ViewModels/ConfirmReminderViewModel.swift`
- `YijuhuaTixing/ViewModels/TaskDetailViewModel.swift`
- `YijuhuaTixing/Views/Confirm/ConfirmReminderSheet.swift`
- `YijuhuaTixing/Views/Detail/TaskDetailView.swift`
- `YijuhuaTixing/Resources/Info.plist`
- `YijuhuaTixing/Tests/ReminderParserTests.swift`
- `YijuhuaTixing/Tests/ReminderStoreTests.swift`
- `YijuhuaTixing/Tests/Resources/yijuhua-tixing-nlp-test-corpus-v0.1.jsonl`

Read the relevant reference before changing code:

- `references/address-navigation.md`
- `references/parser-dot-number-rules.md`
- `references/wheel-time-picker-hit-area.md`
