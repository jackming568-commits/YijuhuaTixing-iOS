# Wheel Time Picker Hit Area

Use this reference when the create-confirm page or reminder detail page has a wheel time picker that interferes with vertical scrolling.

## User Problem

- The user scrolls down to fields below the time picker, such as address input.
- Wide hidden wheel hit areas accidentally change the selected time.
- Shrinking only the gray selected capsule is not enough if the real touch area remains wider.
- The target is: gray selected capsule width should match the real wheel-adjustable area, and the outside area should remain usable for page vertical scrolling.

## Final Product Behavior

- Apply the same picker behavior to:
  - `YijuhuaTixing/Views/Confirm/ConfirmReminderSheet.swift`
  - `YijuhuaTixing/Views/Detail/TaskDetailView.swift`
- Use a `240pt` real interactive width for the time wheel.
- Let the gray selected capsule follow that same width.
- Keep the system wheel content centered:

```swift
datePicker.center = CGPoint(x: bounds.midX, y: bounds.midY)
```

- Do not use a manual whole-control offset such as `contentCenterOffsetX` as the final fix. The user's goal is for the time digits to look centered inside the capsule, not for the whole system picker to drift sideways.

## Implementation Pattern

Prefer a UIKit wrapper around `UIDatePicker`:

- `HitLimitedWheelTimePicker: UIViewRepresentable`
- `HitLimitedWheelTimePickerView: UIView`
- `clipsToBounds = true`
- `datePicker.datePickerMode = .time`
- `datePicker.preferredDatePickerStyle = .wheels`
- `datePicker.minuteInterval = 1`
- `datePicker.locale = Locale(identifier: "en_GB")`
- `datePicker.semanticContentAttribute = .forceLeftToRight`

Limit real touch handling at the wrapper boundary:

```swift
override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    isUserInteractionEnabled && bounds.contains(point)
}

override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard bounds.contains(point) else {
        return nil
    }
    return super.hitTest(point, with: event)
}
```

Place the picker inside the limited wrapper:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    let pickerHeight = max(datePicker.intrinsicContentSize.height, bounds.height)
    datePicker.bounds = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: pickerHeight))
    datePicker.center = CGPoint(x: bounds.midX, y: bounds.midY)
}
```

Call both pages with:

```swift
HitLimitedWheelTimePicker(
    selection: $draftRemindAt,
    isEnabled: !showCalendarPicker,
    width: 240
)
```

## Avoid

- Do not solve this only with SwiftUI `.frame(width:)` and `.clipped()`, because the visual crop can diverge from UIKit's internal gesture hit area.
- Do not keep narrowing below the usable width after the user accepts `240pt`; earlier `196pt` and `212pt` felt too small.
- Do not reintroduce `contentCenterOffsetX` unless the user explicitly asks to experiment. It moves the whole picker content and can make the control itself feel off-center.

## Validation

Minimum checks:

- In both create-confirm and detail pages, vertical swipes outside the capsule should scroll the page instead of changing time.
- Dragging inside the capsule should still adjust hour/minute normally.
- The gray selected capsule should remain pill-shaped and centered.
- The time digits should visually sit inside the capsule, with the system picker content centered first.
- `xcodebuild build-for-testing` should pass after changes.

## Escalation Path

If pixel-perfect digit centering is still required, consider a custom hour/minute wheel instead of more `UIDatePicker` offsets. System `UIDatePicker` does not expose reliable column-level layout controls.
