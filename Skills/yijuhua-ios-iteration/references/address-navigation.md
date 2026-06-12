# Address Navigation

## Product Scope

The `1.2` address feature is "address note + external map navigation" only.

Do not add:

- Map SDKs.
- Location permission.
- In-app map.
- POI search.
- Location-based reminders.
- Address upload or analytics about installed map apps.

The feature belongs below the time/repeat controls in the create-confirm and detail flows, so it does not disturb the main reminder interaction.

## Persistence

- Add `addressText: String?` to `Reminder`.
- Bump SwiftData schema, using lightweight migration for old reminders.
- Old reminders should read as `nil` address.
- Trim address input before saving.
- Save blank address as `nil`.
- Include address in `ReminderStore.update(...)`.
- If notification rescheduling fails during update, roll back the old address with the other reminder fields.

## UI Behavior

Create-confirm page:

- Show an optional address input.
- Let the user confirm the address.
- Show map navigation when address is non-empty.
- Save address together with the reminder.

Detail page:

- Show an optional address input.
- Address changes must enable Save.
- Save button should have clear enabled, saving, and saved states.
- After save success, show visible feedback before dismissing.
- Address navigation should be available for the saved or current non-empty address.

## External Navigation

Use URL schemes and system links only:

- Apple Maps: system map URL fallback.
- Amap: `iosamap://`
- Baidu: `baidumap://`
- Tencent: `qqmap://`

Use `UIApplication.canOpenURL` only for installed-app detection.

Generated Info.plist may not reliably emit array build settings, so if schemes do not appear in the app bundle, use an explicit `Resources/Info.plist` and include:

- `maps`
- `iosamap`
- `baidumap`
- `qqmap`

If no usable map app is detected:

- Alert title: `未检测到可用地图 App`
- Button: `去 App Store 下载地图`
- Open App Store search for `地图导航`.

## Review Notes

Recommended App Review note:

`地址仅保存在本机，用于用户主动跳转系统或第三方地图导航；本 App 不申请定位权限，不在 App 内展示地图，也不上传地址。`

## Validation

Minimum checks:

- Old reminders open after migration.
- Empty address keeps the current reminder flow unchanged.
- Non-empty address saves, reopens, and displays.
- Installed third-party map apps appear as options.
- Missing third-party apps do not crash.
- No installed map app path opens App Store search.
- No location permission prompt appears.
- `xcodebuild build-for-testing` passes.
