# 一句话提醒账号契约

日期：2026-06-05

目标：为登录、个人中心、会员、打点和管理后台提供统一账号 ID。后续所有窗口必须复用本契约，不单独发明用户字段。

## 决策

- 首发市场：中国大陆。
- 首版后端路线：腾讯云 BaaS / 云函数 / 云数据库 / 腾讯云短信。
- 首版登录方式：手机号 + 短信验证码注册/登录。
- 密码能力：个人中心里可选设置/修改，用于后续手机号 + 密码登录和找回密码。
- 账号删除：App 内必须提供注销账号入口，路径放在 `设置 -> 个人信息 -> 注销账号`。
- 用户唯一标识：后端生成稳定 `user_id`，iOS、会员、打点、后台都使用它串联数据。

## 用户模型

`UserProfile`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_id` | String | 是 | 后端生成，建议 ULID / UUID，不使用手机号作为主键 |
| `phone_country_code` | String | 是 | 中国大陆默认 `+86` |
| `phone_masked` | String | 是 | 脱敏展示，例如 `138****1234` |
| `nickname` | String | 是 | 默认 `一句话用户` + 短 ID，可修改 |
| `avatar_url` | String? | 否 | 首版可为空 |
| `password_set` | Bool | 是 | 是否已设置密码 |
| `account_status` | String | 是 | `active` / `deleting` / `deleted` |
| `created_at` | ISO8601 String | 是 | 注册时间 |
| `last_login_at` | ISO8601 String | 是 | 最近登录时间 |
| `membership_status` | String | 是 | `free` / `trial` / `active` / `grace_period` / `expired` |
| `membership_expires_at` | ISO8601 String? | 否 | 会员到期时间 |

本地存储：

- Keychain：`access_token`、`refresh_token`、`user_id`。
- UserDefaults：`phone_masked`、`nickname`、`membership_status` 的只读缓存。
- 退出登录时清理 token 和账号缓存，不删除本地提醒数据。
- 注销账号成功后清理 token、账号缓存和会员缓存；本地提醒数据是否删除由注销确认页提示用户选择，首版默认保留本机数据但从云端删除账号数据。

## API 契约

所有 API 默认前缀：`/v1`

### 发送短信验证码

`POST /auth/sms-code`

请求：

```json
{
  "phone_country_code": "+86",
  "phone_number": "13812341234",
  "purpose": "login",
  "device_id": "ios-install-id"
}
```

`purpose` 可选值：

- `login`
- `set_password`
- `reset_password`
- `delete_account`

成功响应：

```json
{
  "request_id": "sms_req_01",
  "cooldown_seconds": 60,
  "expires_in_seconds": 300
}
```

失败要求：

- 同一手机号 60 秒内不重复发送。
- 同一手机号每天验证码次数限制，默认 10 次。
- 同一设备每天验证码次数限制，默认 20 次。
- 返回通用错误文案，不暴露该手机号是否已注册。

### 验证码登录/注册

`POST /auth/verify-code`

请求：

```json
{
  "phone_country_code": "+86",
  "phone_number": "13812341234",
  "code": "123456",
  "device_id": "ios-install-id",
  "app_version": "1.0.0"
}
```

成功响应：

```json
{
  "is_new_user": true,
  "access_token": "jwt-access-token",
  "refresh_token": "jwt-refresh-token",
  "profile": {
    "user_id": "usr_01HY...",
    "phone_country_code": "+86",
    "phone_masked": "138****1234",
    "nickname": "一句话用户01HY",
    "avatar_url": null,
    "password_set": false,
    "account_status": "active",
    "created_at": "2026-06-05T12:00:00+08:00",
    "last_login_at": "2026-06-05T12:00:00+08:00",
    "membership_status": "free",
    "membership_expires_at": null
  }
}
```

打点：

- 新用户：`register_success`
- 老用户：`login_success`

### 刷新 token

`POST /auth/refresh`

请求：

```json
{
  "refresh_token": "jwt-refresh-token"
}
```

成功响应：

```json
{
  "access_token": "new-jwt-access-token",
  "refresh_token": "new-jwt-refresh-token"
}
```

### 获取个人信息

`GET /me`

Header：`Authorization: Bearer <access_token>`

成功响应：

```json
{
  "profile": {
    "user_id": "usr_01HY...",
    "phone_country_code": "+86",
    "phone_masked": "138****1234",
    "nickname": "一句话用户01HY",
    "avatar_url": null,
    "password_set": false,
    "account_status": "active",
    "created_at": "2026-06-05T12:00:00+08:00",
    "last_login_at": "2026-06-05T12:00:00+08:00",
    "membership_status": "active",
    "membership_expires_at": "2027-06-05T12:00:00+08:00"
  }
}
```

### 修改个人信息

`PATCH /me`

请求：

```json
{
  "nickname": "高效工作者"
}
```

规则：

- `nickname` 长度 1-20 个字符。
- 不允许纯空格。
- 首版不做头像上传。

### 设置/修改密码

`POST /me/password`

请求：

```json
{
  "sms_code": "123456",
  "new_password": "user-password"
}
```

规则：

- 密码长度 8-32。
- 必须包含字母和数字。
- 后端只保存加盐哈希，不保存明文。

### 退出登录

`POST /auth/logout`

行为：

- 后端使当前 refresh token 失效。
- iOS 清理 token 和账号缓存。
- 不删除本机提醒。

### 注销账号

`POST /me/delete`

请求：

```json
{
  "sms_code": "123456",
  "reason": "user_requested"
}
```

行为：

- 账号状态改为 `deleting`。
- 立即使 token 失效。
- 删除或匿名化用户个人数据、手机号、昵称、事件中的用户关联信息。
- 依法必须保留的订单/交易记录只保留最小必要字段。
- 完成后状态改为 `deleted`。

iOS UI 要求：

- 注销入口容易找到，放在个人信息页底部。
- 注销前二次确认，明确说明删除账号和云端个人数据。
- 可要求短信验证码确认身份。
- 不允许只提供“停用账号”替代删除。

## 个人中心 UI

入口：`设置 -> 个人信息`

已登录：

- 昵称
- 手机号
- 会员状态
- 设置/修改密码
- 订单与会员
- 恢复购买
- 退出登录
- 注销账号

未登录：

- 显示 `登录 / 注册`
- 说明登录后可同步会员权益、查看订单和参与活动。

## 后台管理字段

后台用户列表首版展示：

- 注册时间
- 手机号脱敏
- 昵称
- 会员状态
- 最近登录时间
- 注册渠道
- 首次创建提醒时间
- 购买次数
- 累计收入
- LTV

## 合规依据

- Apple 账号删除要求：支持创建账号的 App 必须允许用户在 App 内发起账号删除。
- 链接：https://developer.apple.com/support/offering-account-deletion-in-your-app/
