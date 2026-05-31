# 真机通知闭环测试清单

## 前置

- 在 Xcode 打开 `ios/YijuhuaTixing.xcodeproj`
- 选择 shared scheme：`YijuhuaTixing`
- 设置 `YijuhuaTixing` target 的 Signing Team
- 使用真机运行 Debug 版本
- 首次测试前删除旧 App，避免历史通知权限状态干扰

## 1. 首次权限

1. 打开 App
2. 输入：`1分钟后提醒我测试通知`
3. 点确认
4. 看到通知权限引导页
5. 点允许
6. 等待 1 分钟

通过标准：

- 系统权限弹窗只在确认提醒后出现
- 到点收到本地通知
- 通知标题为 `一句话提醒`
- 通知正文为任务标题

## 2. 设置页测试通知

1. 打开设置页
2. 点 `1分钟后测试通知`
3. 回到桌面或锁屏
4. 等待 1 分钟

通过标准：

- 设置页显示 `已安排 HH:mm 的测试通知。`
- 到显示的时间收到测试通知
- 今日页能看到 `测试通知`

## 3. 通知动作

1. 创建一个 1 分钟后的提醒
2. 通知到达后长按通知
3. 依次测试：
   - 完成
   - 10分钟后
   - 1小时后
   - 明天早上
4. 再创建一个 1 分钟后的提醒，手动从后台划掉 App
5. 通知到达后直接点 `完成`
6. 重新打开 App

通过标准：

- 完成后任务不再出现在今日待提醒中
- 延后后任务时间被更新
- 延后会重新创建通知
- App 冷启动后，通知动作会先持久缓存，再在今日页就绪后落到任务数据里

## 4. 权限关闭

1. 在系统设置里关闭 App 通知权限
2. 回到 App 创建提醒

通过标准：

- App 仍创建本地任务
- 不崩溃
- 设置页通知状态显示 `已关闭`
- `前往系统设置` 可打开 App 设置页
- 从系统设置回到 App 后，设置页通知状态会自动刷新

## 5. 重复提醒

测试输入：

- `每天早上8点提醒我吃药`
- `每周五18点提醒我写周报`
- `每月1号上午9点提醒我交房租`
- `工作日早上9点提醒我打卡`
- `每隔两小时提醒我喝水`

通过标准：

- 每天 / 每周 / 每月会创建系统重复通知
- 工作日提醒会创建周一到周五 5 个系统重复通知
- 每 2 小时提醒会创建系统时间间隔重复通知
- 重复提醒被 `10分钟后` 延后时，只创建一次临时延后通知，不把延后时间变成永久重复时间

## 6. 过期和冲突输入

测试输入：

- `今天上午10点提醒我给客户发报价`
- `明天10点提醒我发报价，下午3点提醒我回电话`
- `到公司提醒我打卡`
- `每周一三五上午9点提醒我运动`

通过标准：

- 不能直接确认过期或不支持的提醒
- 确认卡片给出明确提示
- 用户修改成未来时间后才能确认

## 7. 回归基线

每次改解析器后运行：

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

通过标准：

- `Passed: 208/208`
