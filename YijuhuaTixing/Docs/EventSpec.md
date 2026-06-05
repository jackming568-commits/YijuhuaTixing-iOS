# 一句话提醒打点与后台指标契约

日期：2026-06-05

目标：统一 App、后端、第三方移动统计、买量归因和管理后台使用的事件名称、属性、指标口径。后续所有窗口必须按本文件埋点和算数。

## 决策

- 首版采用“第三方移动统计/归因 + 自建后台”。
- iOS 事件同时发送到：
  - 自建后端 `/v1/events/batch`
  - 第三方移动统计 SDK 适配器
- 不上传任务正文、语音原文、手机号明文。
- 事件属性只允许上传标签、入口、是否语音、是否 Siri、时间桶、会员状态、渠道等非敏感字段。
- 默认国内首发：第三方产品分析优先选神策分析或友盟+；买量规模化后接 AppsFlyer / Adjust / 渠道归因，SDK 接入必须通过适配器封装，不能散落在业务代码里。

## 身份体系

| 字段 | 说明 |
| --- | --- |
| `anonymous_id` | 未登录前生成的安装级 ID，存 Keychain |
| `user_id` | 登录后后端生成的稳定用户 ID |
| `device_id` | 设备/安装 ID，不使用 IDFA 作为唯一依据 |
| `session_id` | App 冷启动生成，退出或长时间后台后刷新 |
| `app_version` | App 版本 |
| `membership_status` | `free` / `trial` / `active` / `grace_period` / `expired` / `revoked` |

登录后必须做 identity 绑定：

- 自建后端：同一个事件允许同时带 `anonymous_id` 和 `user_id`。
- 第三方统计：调用 identify / login 类接口，把匿名行为合并到登录用户。

## 通用事件属性

所有事件默认附带：

```json
{
  "event_id": "evt_01HY...",
  "event_name": "reminder_created",
  "occurred_at": "2026-06-05T12:00:00+08:00",
  "anonymous_id": "anon_01HY...",
  "user_id": "usr_01HY...",
  "session_id": "ses_01HY...",
  "app_version": "1.0.0",
  "platform": "ios",
  "os_version": "iOS 18.5",
  "membership_status": "free",
  "channel": "organic",
  "campaign_id": null,
  "adgroup_id": null,
  "creative_id": null,
  "properties": {}
}
```

归因字段：

- `channel`
- `campaign_id`
- `campaign_name`
- `adgroup_id`
- `adgroup_name`
- `creative_id`
- `creative_name`
- `keyword`
- `storefront`
- `attribution_provider`

首版没有归因时：

- `channel = organic`
- 付费渠道数据以后端导入或第三方归因回传为准。

## 事件列表

### 获客与启动

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `app_install_detected` | 首次启动检测到新安装 | `install_source` |
| `app_open` | 每次 App 打开 | `launch_type` |
| `session_start` | 新 session 开始 | `launch_type` |
| `onboarding_viewed` | 新用户看到首屏引导 | `step` |

### 账号

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `sms_code_requested` | 请求验证码 | `purpose` |
| `sms_code_request_failed` | 验证码发送失败 | `reason` |
| `register_success` | 新手机号首次验证码登录成功 | `method` |
| `login_success` | 老用户登录成功 | `method` |
| `logout` | 用户退出登录 | 无 |
| `profile_updated` | 修改昵称等资料 | `field` |
| `password_set` | 设置/修改密码成功 | `source` |
| `account_delete_requested` | 发起注销 | `source` |
| `account_deleted` | 注销完成 | `source` |

### 核心使用

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `input_started` | 用户开始输入 | `source` |
| `input_submitted` | 提交自然语言输入 | `source` |
| `parse_succeeded` | 解析成功 | `confidence`, `has_repeat`, `tag`, `time_bucket` |
| `parse_failed` | 解析失败 | `missing_fields` |
| `confirmation_shown` | 进入确认提醒页 | `source`, `tag` |
| `reminder_created` | 创建提醒成功 | `source`, `tag`, `has_repeat`, `time_bucket` |
| `reminder_completed` | 完成提醒 | `source`, `is_overdue` |
| `reminder_deleted` | 删除提醒 | `source` |
| `reminder_restored` | 历史记录恢复提醒 | `from_status`, `is_overdue` |
| `reminder_snoozed` | 稍后提醒 | `snooze_option` |
| `tag_filter_used` | 使用标签筛选 | `tag` |
| `search_used` | 使用搜索 | `screen` |

`source` 可选值：

- `quick_input`
- `voice_input`
- `siri_shortcut`
- `detail_edit`
- `history_restore`
- `notification_action`

`time_bucket` 可选值：

- `overdue`
- `today`
- `this_week`
- `this_month`
- `this_quarter`
- `half_year`
- `one_year`
- `two_years`
- `three_years`
- `five_years`
- `after_five_years`

### 通知

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `notification_permission_requested` | 请求通知权限 | `source` |
| `notification_permission_granted` | 通知权限允许 | `source` |
| `notification_permission_denied` | 通知权限拒绝 | `source` |
| `notification_preview_hidden_detected` | 检测到通知预览隐藏 | `source` |
| `notification_preview_hint_shown` | 展示预览引导 | `source` |
| `test_notification_scheduled` | 设置页测试通知 | 无 |

### 语音与 Siri

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `voice_input_started` | 开始语音输入 | `screen` |
| `voice_input_result_received` | 收到语音识别结果 | `screen`, `duration_bucket` |
| `voice_input_failed` | 语音输入失败 | `reason` |
| `siri_reminder_created` | Siri/快捷指令创建成功 | `tag`, `time_bucket` |
| `siri_reminder_failed` | Siri/快捷指令创建失败 | `reason` |

### 会员

| 事件名 | 触发时机 | 关键属性 |
| --- | --- | --- |
| `membership_page_viewed` | 会员页曝光 | `source` |
| `pro_feature_blocked` | 免费用户触发 Pro 功能 | `feature`, `source` |
| `subscription_product_loaded` | StoreKit 商品加载成功 | `product_count` |
| `trial_started` | 免费试用开始 | `product_id` |
| `subscription_purchased` | 首次购买成功 | `product_id`, `price`, `currency` |
| `subscription_purchase_canceled` | 用户取消购买 | `product_id` |
| `subscription_purchase_failed` | 购买失败 | `product_id`, `reason` |
| `subscription_restored` | 恢复购买成功 | `product_id` |
| `subscription_renewed` | 自动续费成功 | `product_id` |
| `subscription_canceled` | 关闭自动续费 | `product_id` |
| `subscription_expired` | 订阅过期 | `product_id` |
| `subscription_refunded` | 退款/撤销 | `product_id` |

## 事件 API

`POST /v1/events/batch`

请求：

```json
{
  "events": [
    {
      "event_id": "evt_01HY...",
      "event_name": "reminder_created",
      "occurred_at": "2026-06-05T12:00:00+08:00",
      "anonymous_id": "anon_01HY...",
      "user_id": "usr_01HY...",
      "session_id": "ses_01HY...",
      "app_version": "1.0.0",
      "platform": "ios",
      "os_version": "iOS 18.5",
      "membership_status": "free",
      "channel": "organic",
      "campaign_id": null,
      "adgroup_id": null,
      "creative_id": null,
      "properties": {
        "source": "quick_input",
        "tag": "daily_life",
        "time_bucket": "today",
        "has_repeat": "false"
      }
    }
  ]
}
```

响应：

```json
{
  "accepted": 1,
  "rejected": 0
}
```

要求：

- iOS 支持批量上报。
- 离线时本地队列暂存，最多保留 500 条或 7 天。
- `event_id` 用于后端去重。
- 后端不因单条无效事件拒绝整个 batch。

## 指标口径

| 指标 | 口径 |
| --- | --- |
| 下载量 | App Store Connect / 归因平台安装数据 |
| 注册量 | `register_success` 去重用户数 |
| 登录量 | `login_success` 去重用户数 |
| DAU | 当日触发任意有效事件的去重 `user_id`，未登录用 `anonymous_id` |
| MAU | 30 日内触发任意有效事件的去重用户数 |
| 激活用户 | 注册后 24 小时内成功创建第一条提醒 |
| D1 留存 | 注册次日仍触发有效事件的用户 / 注册用户 |
| D7 留存 | 注册第 7 日仍触发有效事件的用户 / 注册用户 |
| D30 留存 | 注册第 30 日仍触发有效事件的用户 / 注册用户 |
| 试用率 | `trial_started` 用户数 / 注册用户数 |
| 付费率 | `subscription_purchased` 用户数 / 注册用户数 |
| 购买量 | `subscription_purchased` 次数 |
| 付费用户数 | 有有效付费或试用后转付费记录的用户数 |
| ARPU | 总收入 / 活跃用户数 |
| ARPPU | 总收入 / 付费用户数 |
| LTV | 用户从注册至统计日累计净收入 |
| CAC | 渠道花费 / 新注册用户数 |
| ROI | 净收入 / 渠道花费 |
| 退款率 | `subscription_refunded` 金额 / 购买金额 |

收入口径：

- 后台收入以 Apple 交易和 App Store Server Notifications 为准。
- 事件中的 `price` 只用于漏斗分析，不作为财务最终口径。

## 管理后台首页

首版后台只读。

布局：

1. 顶部日期筛选：今天、昨天、近 7 天、近 30 天、自定义。
2. KPI 卡片：
   - 下载量
   - 注册量
   - 登录量
   - DAU
   - MAU
   - 付费用户
   - 订阅收入
   - 退款金额
3. 买量 ROI 表：
   - 渠道
   - 计划
   - 素材
   - 花费
   - 注册数
   - 注册成本
   - 付费数
   - 付费成本
   - LTV
   - ROI
4. 漏斗：
   - 下载
   - 注册
   - 创建首个提醒
   - 试用
   - 付费
5. 留存：
   - D1 / D7 / D30 cohort 表。
6. 会员：
   - 试用人数
   - 试用转付费率
   - 月/季/年占比
   - 续费
   - 取消
   - 退款
7. LTV：
   - 按渠道
   - 按注册日期
   - 按会员套餐

后台筛选维度：

- 日期
- 渠道
- 广告计划
- 素材
- 会员状态
- 会员套餐
- App 版本

## 隐私与合规

禁止上传：

- 任务标题全文
- 原始输入全文
- 语音识别全文
- 手机号明文
- 用户密码
- Apple transaction JWS 到第三方统计平台

允许上传：

- 标签 rawValue
- 时间分组
- 是否重复提醒
- 是否语音创建
- 是否 Siri 创建
- 会员状态
- 渠道归因字段

## 测试

iOS：

- 每个关键路径事件只触发一次。
- 登录前后 identity 合并正确。
- 离线事件恢复网络后能批量上报。
- 不上传任务正文。

后端：

- `event_id` 去重。
- 批量事件部分失败不影响有效事件入库。
- 指标计算和事件表对得上。

后台：

- 日期筛选正确。
- 渠道筛选正确。
- 漏斗、留存、LTV 口径一致。

## 参考

- App Store Connect App Analytics：https://developer.apple.com/app-store/app-analytics/
- Apple AdAttributionKit：https://developer.apple.com/app-store/ad-attribution/
- Apple App Store Server Notifications：https://developer.apple.com/documentation/appstoreservernotifications/app-store-server-notifications-v2
