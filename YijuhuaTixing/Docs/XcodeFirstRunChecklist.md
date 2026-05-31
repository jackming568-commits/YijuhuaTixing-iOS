# Xcode 首次运行清单

## 目标

把 `一句话提醒` 从源码工程跑到真机上，完成第一轮编译、权限、通知、任务数据闭环验证。

## 打开工程

1. 用 Xcode 打开：

   ```text
   /Users/mingjack/AI文件/Codex/ios/YijuhuaTixing.xcodeproj
   ```

2. 选择 shared scheme：

   ```text
   YijuhuaTixing
   ```

3. 选择真机作为运行目标。

## Signing

1. 进入 `YijuhuaTixing` target
2. 打开 `Signing & Capabilities`
3. 设置自己的 Team
4. 保持 `Automatically manage signing` 开启

当前 bundle id：

```text
com.yijuhua.tixing
```

如果这个 id 被占用，可以改成自己的反域名，例如：

```text
com.mingjack.yijuhuatixing
```

## 第一轮编译

1. 按 `Cmd + B` 先 Build
2. 如果通过，再按 `Cmd + R` 真机运行
3. 首次运行后打开设置页，确认 Debug 区域显示：

   ```text
   1分钟后测试通知
   ```

Debug build 已显式开启：

```text
ENABLE_TESTABILITY = YES
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
```

## 第一轮功能验证

按顺序测试：

1. 打开 App，确认今日页能展示
2. 输入 `1分钟后提醒我测试通知`
3. 确认解析卡片展示任务和未来时间
4. 点确认
5. 首次弹出通知权限引导
6. 允许通知
7. 等待 1 分钟，确认收到通知
8. 长按通知测试 `完成`
9. 回到 App，确认任务状态更新

完整通知闭环测试见：

```text
ios/YijuhuaTixing/Docs/DeviceNotificationTestChecklist.md
```

## 单测

在 Xcode 中运行：

```text
YijuhuaTixingTests
```

重点确认：

- `ReminderParserTests`
- `ReminderStoreTests`
- `RepeatRuleTests`
- `NotificationActionRouterTests`
- `NotificationServiceTriggerTests`

如果 `@testable import YijuhuaTixing` 失败，先检查当前是不是 Debug configuration。

## 命令行解析器回归

当前机器没有完整 Xcode / iPhone Simulator SDK 时，仍可运行纯规则解析 smoke test：

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

当前基线：

```text
Passed: 208/208
```

## 当前限制

当前本机已可使用 Xcode 16.4 跑通 `xcodebuild` 和 iPhone 16 Simulator 测试；真机通知和 TestFlight 前检查仍需要在本机 Xcode 中手动完成。
