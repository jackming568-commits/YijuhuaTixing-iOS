---
name: ios-indie-app-launch
description: Use when guiding an individual iOS developer through App Store Connect launch work, especially mainland China ICP/App ICP constraints, Hong Kong/Macau first release strategy, StoreKit subscription metadata, App Review setup, Xcode archive upload, screenshots, pricing, and release blockers.
metadata:
  short-description: Guide iOS App Store launch, ICP, IAP, screenshots, and review submission
---

# iOS Indie App Launch

Use this skill to keep an individual iOS app launch moving through App Store Connect with minimal rework and low review risk.

## Working Style

- Lead with the next blocker and the next 1-3 clicks/actions.
- Separate what must be done in App Store Connect from what requires code or Xcode.
- Do not recommend broad region launches when ICP, DSA, tax, bank, or legal pages are unfinished.
- If a page shows a yellow or red warning, resolve that warning before inventing new work.
- Avoid changing product IDs after App Store Connect subscriptions are created.

## Region Strategy

- If mainland China ICP/App ICP is not ready, do not include mainland China in the first release.
- A practical first release can use Hong Kong and Macau only:
  - App availability: Hong Kong, Macau.
  - Subscription availability: Hong Kong, Macau.
  - Do not select mainland China, EU countries, United States, or broad "all regions" unless intentionally launching there.
- If EU is not selected, DSA trader status can wait.
- If mainland China is not selected, China mainland ICP number can wait.
- If the user insists on mainland China first, stop submission and make ICP/App ICP the blocker.

## App Store Connect Submission Checklist

For each version submission:

1. Select the correct uploaded build.
   - Prefer the newest build that has export compliance resolved.
   - Do not select old builds with "missing export compliance" warnings.
2. Confirm app availability matches the intended first-release regions.
3. Confirm screenshots do not contradict selected regions or pricing.
   - For Hong Kong/Macau only, avoid screenshots or subscription images that show mainland RMB prices.
   - iPhone screenshots need at least 3 images; remove optional monetization screenshots if they create pricing mismatch.
4. Select IAP/subscriptions on the app version page before submitting the first subscription review.
5. Save App Review notes and contact info.
6. Click "Add for Review" only after all required metadata warnings are gone.

## IAP Subscription Checklist

Keep subscriptions in one group, ordered from highest service level or preferred order as App Store Connect requires.

For each subscription product:

- Reference name is internal; display name and description are customer-facing.
- Product ID must remain stable after creation.
- Duration must match the intended tier.
- Sales availability must match app availability.
- Price should be selected from Apple's available price tiers; choose the closest practical local tier.
- Localized display name and description are required for review.
- Optional 1024 x 1024 subscription image can be omitted if it causes trouble.

Hong Kong/Macau first-release pricing pattern:

```text
Monthly:
Hong Kong: about HK$8
Macau: about US$0.99

Quarterly:
Hong Kong: about HK$18
Macau: about US$2.99 or US$3.99

Annual:
Hong Kong: about HK$68
Macau: about US$9.99
```

## Yijuhua Reminder Constants

Use these for the `一句话提醒` project unless the user explicitly changes them:

```text
App name: 一句话提醒
Bundle ID: com.yijuhua.tixing
SKU: yijuhua-tixing-ios
Apple ID: 6778316481
Version: 1.0
Current build to submit: 2
Team ID: L5DPYM5VD2
Primary category: 效率
```

Subscription group:

```text
Reference Name: yijuhua_pro
Display Name: 一句话提醒 Pro
```

Subscription product IDs:

```text
Monthly: com.yijuhua.pro.monthly
Quarterly: com.yijuhua.pro.quarterly
Annual: com.yijuhua.pro.annual
```

Do not change annual back to `com.yijuhua.pro.yearly`.

## Xcode Upload Notes

- Archive with the enrolled developer team, not a personal team.
- Use `Any iOS Device (arm64)` for archiving.
- In Organizer, distribute via `App Store Connect`.
- If App Store Connect reports export compliance, set `ITSAppUsesNonExemptEncryption = NO` when the app does not use non-exempt encryption.
- If a new archive uploads successfully, wait for App Store Connect processing before selecting it.

## Review Notes

If the app core does not require login, do not check "Sign-in required".

Reusable review note:

```text
本 App 是一款本地提醒工具，核心功能无需登录即可测试。

测试方式：
1. 打开 App，在首页输入“明天上午10点提醒我喝水”。
2. 进入确认页后点击“确认提醒”。
3. 可在“设置 > 会员中心”查看订阅入口。
```

## Do Not Fill Unless Applicable

- Router app coverage file: only for navigation/routing apps.
- Encryption documentation: only if the app uses non-exempt encryption.
- Mainland China ICP number: only when launching in mainland China.
- EU DSA trader status: only when launching in EU regions.
- Vietnam game license: only for games in Vietnam.
- Regulated medical device declaration: only for medical/health regulated device apps.

## Local Validation

Before telling the user to submit:

- Confirm latest build number and product IDs in the repo when code access is available.
- Run the narrowest relevant validation, usually:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/yijuhua-clang-module-cache xcodebuild build-for-testing -project YijuhuaTixing.xcodeproj -scheme YijuhuaTixing -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/yijuhua-derived-data
```

- If screenshots or images are being prepared, confirm dimensions before upload.

## Output Pattern

Answer in this order:

1. Current status or blocker.
2. Exact next action.
3. Fields or values to enter.
4. What can wait.

Keep long handoff summaries only for explicit handoff requests.
