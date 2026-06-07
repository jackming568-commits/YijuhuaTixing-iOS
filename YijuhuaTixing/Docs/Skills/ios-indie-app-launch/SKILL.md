---
name: ios-indie-app-launch
description: Use when helping a solo or individual developer launch an iOS app, especially App Store Connect setup, Apple Developer Program readiness, mainland China ICP/App ICP filing, Tencent Cloud or other cloud services, domain/HTTPS/legal pages, StoreKit IAP subscriptions, App Store review materials, launch cost control, and pre-submission testing.
metadata:
  short-description: Guide iOS indie app launch, ICP, IAP, and review readiness
---

# iOS Indie App Launch

Use this skill to drive a small iOS app from local build to App Store submission, with a practical bias for individual developers in mainland China.

## Operating Style

- Keep the user focused on the next bottleneck, not the whole mountain.
- Separate decisions into: user must do, agent can do, wait for review.
- Prioritize tasks with review latency: Apple Developer activation, ICP/App ICP filing, IAP setup, legal/support URLs.
- Avoid premature spend. Do not recommend SMS, attribution, paid analytics, or marketing tools until the product path requires them.
- Verify current Apple, ICP, cloud, and pricing rules before giving specific current claims.
- When the user is a personal developer, assume no company entity unless stated.

## First Pass Checklist

Capture only the minimum launch state:

- App name, bundle ID, SKU, support email.
- Developer type: individual or company.
- Apple Developer Program status.
- Target markets: China mainland only, global, or both.
- Monetization: free, paid, IAP subscription, or no monetization yet.
- Cloud need: none, static legal pages, backend API, admin/data dashboard.
- Domain status: purchased,实名, DNS, HTTPS, ICP.
- Required legal pages: privacy, terms, membership/service agreement, support.

Then give a short "current blocker + next action" answer.

## Recommended Sequence

1. Apple Developer Program
   - Individual developers can publish apps on the App Store.
   - Confirm enrollment is approved before relying on App Store Connect features.
   - Apple annual fee is separate from cloud, domain, and filing costs.

2. Domain and Cloud
   - For a mainland China server, domain实名, cloud实名, and filing主体 should be consistent.
   - Buy only one basic server first if a backend/legal site is needed.
   - Use a low-cost 1-year entry server for launch validation; upgrade after usage proves need.
   - Do not buy DNS paid plans, SSL paid certificates, SMS, or attribution by default.

3. ICP and App ICP
   - If using mainland China cloud resources with a domain, start website ICP early.
   - Unfiled domains pointing to mainland cloud resources may be blocked at the provider layer, even if Nginx and HTTPS are correct.
   - Use a non-sensitive personal site description: product info, privacy policy, terms, support.
   - Avoid descriptions that imply news, publishing, education, medical, finance, games, forum/community, ecommerce, or other pre-approval categories unless actually applicable.
   - After website ICP, handle App ICP when required by the app store/mainland distribution path.

4. Backend and Legal Pages
   - Minimum backend can serve:
     - `/privacy`
     - `/terms`
     - `/membership` when IAP/subscription exists
     - `/support`
     - `/health`
   - Use HTTPS for production URLs.
   - For Let's Encrypt, ensure port 80/443 firewall rules and Nginx server blocks are correct.
   - If mainland ICP is pending, do not mistake provider备案拦截 for app or Nginx failure.

5. IAP Subscriptions
   - Create a subscription group and stable product IDs.
   - Keep tier count small: monthly, quarterly, yearly is enough.
   - If offering a trial, configure it in App Store Connect as an introductory offer/free trial.
   - Test with StoreKit/sandbox before submitting.
   - Legal copy must mention auto-renewal, trial, cancellation, and Apple payment handling.

6. App Store Materials
   - Prepare subtitle, description, keywords, support URL, privacy URL, review notes.
   - Screenshot set should focus on the core job-to-be-done, not secondary automation.
   - Do not make Siri/Shortcuts a hero feature unless the path is genuinely low friction.
   - Review notes should explain account needs, test data, IAP behavior, and any restricted regions.

7. Validation Before Submission
   - Run unit tests/type checks.
   - Test on a real device:
     - core creation flow
     - notification permission and delivery
     - edit/delete/restore
     - subscription gate
     - legal/support links
     - offline and expired-time edge cases
   - Confirm Release builds do not expose Debug-only switches.

## Cost Control Heuristics

- Essential before first submission:
  - Apple Developer annual fee
  - domain
  - one basic server if backend/legal pages are needed
  - optional free Let's Encrypt certificate
- Delay until after launch or paid acquisition:
  - SMS verification
  - AppsFlyer/Adjust
  - 神策/友盟+ paid tiers
  - large cloud upgrades
  - paid DNS/SSL plans
- For analytics, begin with lightweight backend event collection or free tools.

## Personal Developer Notes

- Individual Apple developer accounts can publish apps, but the seller name may show personal name.
- Personal ICP is possible for non-commercial personal websites, but wording matters.
- Keep filing descriptions plain and narrow: product introduction, policy pages, support contact.
- If the user has no company entity, avoid recommending company-only services unless there is a clear reason.

## Common Decisions

- **Mainland backend or not**: Use mainland only when China access/备案 is acceptable; otherwise use overseas static hosting for legal pages.
- **Admin dashboard**: Defer until there is real data or operational need. For launch, logs/metrics endpoints may be enough.
- **Siri/Shortcuts**: Treat as optional automation support. If Siri is hijacked by system apps or requires complex setup, do not position it as a core user benefit.
- **Third-party monitoring**: Start with basic server logs and health checks; add paid monitoring when downtime risk justifies it.

## Reusable Text Snippets

ICP website remark:

```text
本网站为个人开发的效率工具的信息展示页面，主要用于展示产品说明、隐私政策、用户协议和联系支持信息。不涉及新闻、出版、教育、医疗、金融、网络游戏、论坛、社区、电商等需前置审批或经营性网站内容。
```

App Store review note skeleton:

```text
本 App 为个人效率工具，核心功能为创建和管理提醒。
如需测试会员功能，请使用沙盒账号购买或恢复订阅。
隐私政策：<privacy-url>
技术支持：<support-url>
测试建议：创建一条 5 分钟后的提醒，确认本地通知触发。
```

Subscription tier skeleton:

```text
订阅组：<subscription_group>
月度：<bundle>.pro.monthly
季度：<bundle>.pro.quarterly
年度：<bundle>.pro.yearly
免费试用：<duration, if any>
```

## Output Pattern

When helping the user, answer in this order:

1. Current blocker or status.
2. Next 1-3 concrete steps.
3. What the user must provide or do.
4. What can safely wait.

Avoid repeating full launch summaries unless the user asks for a handoff.
