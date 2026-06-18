# 一句话提醒 App Store 上架资料包

日期：2026-06-09

## 当前配置

- App 名称：`一句话提醒`
- Bundle ID：`com.yijuhua.tixing`
- SKU：`yijuhua-tixing-ios`
- Version：`1.0`
- Build：`3`
- Signing Team：`L5DPYM5VD2`
- 主分类：`效率`
- 最低系统：`iOS 17.0`

## App Store Connect 创建 App

- 平台：`iOS`
- 主语言：`简体中文`
- 名称：`一句话提醒`
- Bundle ID：`com.yijuhua.tixing`
- SKU：`yijuhua-tixing-ios`
- 用户访问权限：`Full Access`
- 版权：`2026 曾新明`
- 发布方式：建议 `手动发布`

## App 信息

- 副标题：`一句话创建本地提醒`
- 宣传文本：`输入一句话，自动识别时间，确认后准时提醒。适合快速记录今天、明天、本周和重复提醒。`
- 关键词：`提醒,待办,日程,通知,效率,时间管理,语音输入,快捷指令,备忘,本地提醒`
- 支持 URL：`https://yijuhuatixing.cn/support`
- 隐私政策 URL：`https://yijuhuatixing.cn/privacy`
- 营销 URL：`https://yijuhuatixing.cn`

## 描述

一句话提醒是一款轻量的本地提醒工具。你只需要输入一句自然语言，例如“明天下午 3 点约客户”“每周五 18 点写周报”，App 会自动识别时间和任务内容，确认后创建提醒。

适合这些场景：

- 快速记录临时任务
- 创建今天、明天、本周提醒
- 设置每天、每周、每月重复提醒
- 查看过期提醒和历史记录
- 使用语音输入或快捷指令辅助创建提醒

一句话提醒专注于“快速创建提醒”这件事，不把简单任务做成复杂项目管理。

## 订阅配置

订阅组：

- Reference Name：`yijuhua_pro`
- Display Name：`一句话提醒 Pro`

商品：

| 套餐 | Product ID | 时长 | 价格建议 | 展示名 |
| --- | --- | --- | --- | --- |
| 月度会员 | `com.yijuhua.pro.monthly` | 1 month | `¥8/月` | `月度会员` |
| 季度会员 | `com.yijuhua.pro.quarterly` | 3 months | `¥18/季度` | `季度会员` |
| 年度会员 | `com.yijuhua.pro.annual` | 1 year | `¥68/年` | `年度会员` |

App Store Connect 元数据：

- 促销图片：首版建议删除，不启用 promoted In-App Purchase 图片。
- 展示名：不要包含价格，只保留 `月度会员`、`季度会员`、`年度会员`。
- 描述：不要包含价格，分别使用 `解锁 Pro 功能，按月自动续期`、`解锁 Pro 功能，按季度自动续期`、`解锁 Pro 功能，按年自动续期`。

免费试用：

- 类型：`Introductory Offer / Free Trial`
- 时长：`1 month`
- 三个商品都配置到同一订阅组；用户同一订阅组只应享受一次试用资格。

## 隐私问卷口径

当前上架建议按实际构建填写：

- 核心提醒数据：仅保存在本机。
- 通知：使用系统本地通知。
- 语音输入：使用系统语音识别能力，识别结果填入输入框；不要把语音内容上传到开发者服务器。
- 分析事件：当前 `AppAnalytics` 没有配置远程发送 endpoint，只在本机队列保存。
- 账号：当前 `PersonalCenterView` 使用 `MockAuthService`，不适合作为最终发审登录能力。

如果发审前仍不接正式账号和远程分析，隐私问卷可按“不收集用户数据”准备；一旦启用手机号登录、远程分析或后端同步，需要重新披露手机号、用户 ID、购买信息、产品交互数据等。

## App Review 备注草稿

```
本 App 是一款本地提醒工具，核心功能无需登录即可测试。

测试方式：
1. 打开 App，在首页输入“明天上午10点提醒我喝水”。
2. 进入确认页后点击“确认提醒”。
3. 系统请求通知权限时请选择允许。
4. 可在今日列表、提醒详情、设置页继续测试编辑、删除、历史记录和会员入口。

会员功能使用 StoreKit 2 自动续期订阅：
- com.yijuhua.pro.monthly
- com.yijuhua.pro.quarterly
- com.yijuhua.pro.annual

隐私政策：https://yijuhuatixing.cn/privacy
技术支持：https://yijuhuatixing.cn/support
用户协议：https://yijuhuatixing.cn/terms
会员服务协议：https://yijuhuatixing.cn/membership
使用条款（EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

## 截图清单

- 首页输入：`一句话，创建提醒`
- 确认页：`自动识别时间，确认后提醒`
- 今日列表：`今天要做什么，一眼看清`
- 详情编辑：`时间和内容，都能再调整`
- 历史记录：`误删和完成记录可找回`
- 会员中心：`升级 Pro，解锁完整效率能力`

## 发审前阻塞项

- 中国大陆上架：ICP 备案号未取得前，`yijuhuatixing.cn` 可能被拦截，App Store 中国大陆可用性也可能缺 ICP 信息。
- 账号入口：当前是 `MockAuthService`，发审前要么接正式短信登录，要么隐藏个人信息入口。
- IAP：需要在 App Store Connect 创建订阅组和 3 个 Product ID，否则 StoreKit 商品加载会失败。
- 协议、隐私、支持 URL：备案通过后复测外网 HTTPS 可访问。
- 首次拒审修复：`support/privacy/terms/membership` 必须能通过 HTTPS 打开；App 描述里补 Apple 标准 EULA 链接；删除 IAP 促销图片或重新上传无价格、非截图、非重复的图片。
- 截图：还没有最终 App Store 尺寸截图。
- 付费协议：需要确认 Paid Apps Agreement、税务、银行已完成。

## 官方参考

- App 记录：https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app
- App 信息：https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- 版本信息：https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- App 隐私：https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- 自动续期订阅：https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions
- 免费试用：https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions
