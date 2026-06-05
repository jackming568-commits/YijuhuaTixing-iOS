# 一句话提醒会员订阅契约

日期：2026-06-05

目标：定义首版会员商品、权益、过期策略、StoreKit 2 接入和后端同步规则。后续 iOS、后端、打点和后台都按本契约实现。

## 决策

- 会员类型：App Store 自动续期订阅。
- 首版订阅组：`yijuhua_pro`
- 首版套餐：月度、季度、年度。
- 首月免费：使用 App Store Connect introductory offer 的 free trial。
- 不做 2 年 / 3 年自动续期档位，因为 Apple 自动续期订阅标准时长只有 1 周、1 月、2 月、3 月、6 月、1 年。
- iOS 内解锁数字功能必须使用 Apple In-App Purchase，不接微信/支付宝购买会员。

## 商品定义

| 套餐 | Product ID | 标准时长 | 展示价格 | 说明 |
| --- | --- | --- | --- | --- |
| 月度会员 | `com.yijuhua.pro.monthly` | 1 month | `¥9.9/月` | 适合短期尝试 |
| 季度会员 | `com.yijuhua.pro.quarterly` | 3 months | `¥24.9/季度` | 默认推荐，折合约 `¥8.3/月` |
| 年度会员 | `com.yijuhua.pro.yearly` | 1 year | `¥68/年` | 最优价格，折合约 `¥5.7/月` |

App Store Connect 备注：

- 真实价格以 App Store Connect 可选价格点为准，优先选择最接近上述展示价格的人民币价格点。
- 三个商品放在同一个订阅组内，避免用户同时订阅多个同类套餐。
- 三个商品都配置同一个 introductory free trial，用户在同一订阅组内仅可享受一次试用资格。

## 会员状态

`MembershipStatus`

| 状态 | 说明 |
| --- | --- |
| `free` | 免费用户，未试用、未订阅 |
| `trial` | 免费试用中 |
| `active` | 已付费且有效 |
| `grace_period` | Apple 账单宽限期内，暂时保留权益 |
| `billing_retry` | Apple 正在重试扣费，按服务端通知决定是否保留权益 |
| `expired` | 已过期 |
| `revoked` | 退款或撤销，权益立即失效 |

`MembershipEntitlement`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `user_id` | String | 后端用户 ID |
| `product_id` | String? | 当前有效订阅商品 |
| `original_transaction_id` | String? | Apple 原始交易 ID |
| `membership_status` | String | 见上表 |
| `expires_at` | ISO8601 String? | 到期时间 |
| `trial_used` | Bool | 是否已使用首月免费试用 |
| `auto_renew_status` | Bool? | 是否仍自动续期 |
| `updated_at` | ISO8601 String | 最近更新时间 |

## 权益规则

免费用户：

- 可以查看、完成、删除已有提醒。
- 每天最多创建 3 条提醒。
- 可以使用基础自然语言输入。
- 不开放语音输入、Siri/快捷指令创建、高级标签筛选。

Pro 用户：

- 不限提醒创建数量。
- 可使用语音输入。
- 可使用 Siri / 快捷指令创建提醒。
- 可使用高级标签筛选。
- 可恢复历史已完成 / 已删除任务。
- 后续 AI 解析增强、云同步、跨设备能力默认归入 Pro。

过期策略：

- 会员过期后不会删除用户已有任务。
- 已排程通知继续保留。
- 新建提醒按免费用户限制。
- 进入语音、Siri、高级筛选等 Pro 功能时展示会员引导页。

## iOS StoreKit 2 流程

启动时：

1. 加载 StoreKit 商品列表。
2. 读取当前 transaction entitlements。
3. 本地计算临时会员状态。
4. 登录后调用后端 `/subscriptions/sync` 同步交易。

购买：

1. 用户在会员页选择套餐。
2. StoreKit 发起购买。
3. iOS 验证 transaction。
4. 本地立即解锁权益。
5. 上报后端 `/subscriptions/sync`。
6. 打点 `trial_started` 或 `subscription_purchased`。

恢复购买：

1. 用户点击 `恢复购买`。
2. 调用 StoreKit sync / current entitlements。
3. 重新同步后端。
4. 成功后刷新会员状态。

失败处理：

- StoreKit 购买取消：不报错误弹窗，只轻提示。
- 商品加载失败：显示 `会员信息加载失败，请稍后再试`。
- 后端同步失败：本地基于 verified transaction 临时解锁，并标记待重试。
- 退款/撤销：以后端 App Store Server Notifications 为准，刷新为 `revoked`。

## 后端 API

### 同步订阅状态

`POST /v1/subscriptions/sync`

请求：

```json
{
  "user_id": "usr_01HY...",
  "environment": "Sandbox",
  "transactions": [
    {
      "product_id": "com.yijuhua.pro.yearly",
      "transaction_id": "2000000000000001",
      "original_transaction_id": "2000000000000001",
      "purchase_date": "2026-06-05T12:00:00+08:00",
      "expires_date": "2027-06-05T12:00:00+08:00",
      "revocation_date": null,
      "signed_transaction_info": "jws..."
    }
  ]
}
```

响应：

```json
{
  "entitlement": {
    "user_id": "usr_01HY...",
    "product_id": "com.yijuhua.pro.yearly",
    "original_transaction_id": "2000000000000001",
    "membership_status": "active",
    "expires_at": "2027-06-05T12:00:00+08:00",
    "trial_used": true,
    "auto_renew_status": true,
    "updated_at": "2026-06-05T12:00:00+08:00"
  }
}
```

### 获取会员状态

`GET /v1/subscriptions/current`

响应：

```json
{
  "entitlement": {
    "membership_status": "active",
    "product_id": "com.yijuhua.pro.yearly",
    "expires_at": "2027-06-05T12:00:00+08:00",
    "trial_used": true,
    "auto_renew_status": true
  }
}
```

### App Store Server Notifications

`POST /v1/apple/server-notifications`

要求：

- 验证 Apple JWS。
- 更新订阅状态。
- 处理续费、取消自动续费、扣费重试、宽限期、过期、退款、撤销。
- 写入后台订单/订阅事件表。
- 触发业务事件：`subscription_renewed`、`subscription_canceled`、`subscription_refunded`。

## 会员页 UI

入口：

- 设置页 `会员中心`。
- 免费用户触发 Pro 能力时弹出会员页。
- 创建提醒达到每日 3 条限制时弹出会员页。

页面内容：

- 标题：`升级 Pro，让一句话提醒真正替你省时间`
- 权益列表：
  - 不限提醒数量
  - 语音输入
  - Siri / 快捷指令创建提醒
  - 高级标签筛选
  - 历史误删恢复
- 套餐卡片：
  - 年度会员标记 `最划算`
  - 季度会员标记 `推荐`
  - 月度会员保持普通
- 必须展示：
  - 价格
  - 订阅周期
  - 首月免费试用说明
  - 试用结束后自动续费说明
  - 可随时在 Apple ID 订阅中取消
  - 用户协议、隐私政策、会员服务协议链接
  - `恢复购买`

## 打点

- `membership_page_viewed`
- `subscription_product_loaded`
- `trial_started`
- `subscription_purchased`
- `subscription_purchase_canceled`
- `subscription_purchase_failed`
- `subscription_restored`
- `subscription_expired`
- `subscription_renewed`
- `subscription_canceled`
- `subscription_refunded`
- `pro_feature_blocked`

## 测试

iOS：

- 商品加载成功/失败。
- 月、季、年购买。
- 免费试用资格展示。
- 购买取消。
- 购买成功后本地解锁。
- 恢复购买。
- 过期后降级。
- 无网络时使用本地 verified transaction。

后端：

- `/subscriptions/sync` 正确验证和更新权益。
- Server Notifications 可处理续费、过期、退款。
- 同一个 `original_transaction_id` 不重复记收入。

上架前：

- Sandbox 测试三档套餐。
- TestFlight 测试购买和恢复购买。
- App Review Notes 说明会员功能、免费试用和测试账号。

## 合规依据

- Apple IAP 解锁数字功能要求：https://developer.apple.com/app-store/review/guidelines/
- Apple 自动续期订阅时长：https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/
- Apple introductory offer / free trial：https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/
- App Store Server Notifications V2：https://developer.apple.com/documentation/appstoreservernotifications/app-store-server-notifications-v2
