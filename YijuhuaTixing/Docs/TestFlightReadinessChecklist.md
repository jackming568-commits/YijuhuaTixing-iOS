# TestFlight 前发布检查清单

## 目标

确认 `一句话提醒` 在发给种子用户前，核心链路已经足够可信：

```text
输入一句话 -> 解析 -> 确认 -> 创建本地通知 -> 到点提醒 -> 完成 / 稍后 / 删除
```

这份清单只覆盖 MVP 发版闸口，不把产品扩成复杂待办工具。

## 0. 基本信息

- 检查日期：2026-06-24
- Xcode：16.4
- 模拟器：iPhone 17
- 最低系统：iOS 17+
- 工程：`YijuhuaTixing.xcodeproj`
- Scheme：`YijuhuaTixing`
- App 显示名：`一句话提醒`
- Bundle ID：`com.yijuhua.tixing`
- Version：`1.1`
- Build：`4`
- Signing Team：`L5DPYM5VD2`
- App Icon：`AppIcon`
- Release 检查：设置页 `1分钟后测试通知` 被 `#if DEBUG` 包裹，不进入 Release 体验

## 1. 自动化回归

运行完整测试：

```bash
cd "/Users/guangtuikeji/Documents/New project/YijuhuaTixing-iOS"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project YijuhuaTixing.xcodeproj \
  -scheme YijuhuaTixing \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/YijuhuaTixingDerivedData \
  test
```

通过标准：

- `TEST SUCCEEDED`
- `134 tests, 0 failures`
- `ReminderParserTests/testFullNLPCorpus` 通过
- 语料基线通过

运行 Release 真机构建检查：

```bash
cd "/Users/guangtuikeji/Documents/New project/YijuhuaTixing-iOS"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project YijuhuaTixing.xcodeproj \
  -scheme YijuhuaTixing \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/YijuhuaTixingDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

通过标准：

- `BUILD SUCCEEDED`
- Release 包资源、Info.plist、App Icon、Swift 编译、链接、基础校验均通过
- Debug 专用测试入口不会进入 Release 构建

## 2. 首次权限链路

步骤：

1. 删除旧 App，重新安装
2. 打开 App
3. 输入 `1分钟后提醒我测试通知`
4. 确认提醒
5. 在权限引导页点允许
6. 回到桌面或锁屏等待通知

通过标准：

- 系统通知权限弹窗只在确认提醒后出现
- 允许后提醒被创建
- 今日页出现创建成功轻提示
- 到点收到本地通知
- 通知正文是任务标题

## 3. 权限关闭链路

步骤：

1. 在系统设置中关闭 App 通知权限
2. 回到 App 创建 `10分钟后提醒我喝水`
3. 打开设置页
4. 点 `前往系统设置`
5. 重新开启通知并回到 App

通过标准：

- 提醒会保存到今日列表
- 顶部提示 `已保存提醒，但通知权限未开启，到点不会推送。可前往系统设置开启通知。`
- App 不崩溃、不丢任务
- 设置页权限状态从系统设置返回后自动刷新

## 4. 通知动作闭环

详测见：

```text
ios/YijuhuaTixing/Docs/DeviceNotificationTestChecklist.md
```

TestFlight 前至少完成：

1. 创建 `1分钟后提醒我测试完成`
2. 通知到达后点 `完成`
3. 回到 App，确认任务不再出现在今日待提醒中
4. 创建 `1分钟后提醒我测试稍后`
5. 通知到达后点 `10分钟后`
6. 回到 App，确认任务进入已延后状态
7. 杀掉 App 后再创建一条 1 分钟提醒
8. 通知到达后直接点 `完成`
9. 冷启动 App，确认通知动作落库

通过标准：

- 完成动作能取消后续展示
- 稍后动作会更新提醒时间并重新调度通知
- 冷启动路径不会丢通知动作

## 5. 今日页关键操作

测试项：

- 创建提醒成功后显示 `已创建「标题」`
- 稍后提醒成功后显示 `已延后到 HH:mm`
- 删除提醒后显示 `已删除「标题」`，可撤销
- 撤销删除会恢复未来提醒并重新调度通知
- 右滑完成后提醒从待提醒列表消失
- 点击列表行可进入详情页

通过标准：

- 操作反馈不遮挡输入和列表
- 轻提示能手动关闭，并会自动消失
- 删除撤销失败时能回滚为 deleted 并显示错误

## 6. 详情页编辑

步骤：

1. 创建一个未来提醒
2. 打开详情页
3. 修改标题和时间
4. 保存
5. 再次打开详情页确认数据已更新

通过标准：

- 保存成功后返回今日页
- 保存失败时显示错误
- 调度通知失败时，提醒内容会回滚到编辑前状态
- `已延后` 状态能在详情页正确显示

## 7. 默认时间设置

步骤：

1. 打开设置页
2. 修改早上默认时间和晚上默认时间
3. 输入 `明天早上提醒我开会`
4. 输入 `今晚提醒我看报告`
5. 从通知动作中选择 `明天早上`

通过标准：

- 解析器使用设置中的默认小时
- 确认卡片展示的时间正确
- 稍后提醒和通知动作路由使用同一套默认时间

## 8. 重复提醒

测试输入：

- `每天早上8点提醒我吃药`
- `每周五18点提醒我写周报`
- `每月1号上午9点提醒我交房租`
- `工作日早上9点提醒我打卡`

通过标准：

- 每天 / 每周 / 每月使用系统重复通知
- 工作日会创建周一到周五 5 个系统重复通知
- `每隔两小时` 使用系统时间间隔重复通知
- 重复提醒被延后时，只创建一次临时延后通知

## 9. 解析冒烟样例

必须人工试一遍：

- `半小时后提醒我喝水`
- `一个半小时后提醒我出门`
- `下周一早上提醒我开周会`
- `月底提醒我交房租`
- `下个月底提醒我交房租`
- `周末提醒我整理房间`
- `本周末晚上提醒我整理房间`
- `周日晚上提醒我给妈妈打电话`
- `每隔两小时提醒我喝水`

通过标准：

- 9 条都能进入明确确认流程
- `每隔两小时` 会解析为每 2 小时重复提醒，首个提醒为当前时间 2 小时后
- 低置信度或短标题时，列表行显示原始输入弱提示

## 10. 发版前收口

发 TestFlight 前确认：

- 不新增项目、标签、优先级等复杂待办功能
- 不新增依赖服务端或账号体系
- Debug 专用测试入口不会影响 Release 体验
- App 名称、图标、Bundle ID、Signing Team 已确认
- 种子用户招募文案已准备
- 设置页 `反馈问题` 可打开系统分享反馈模板

## 当前结论

截至 2026-06-24，完整 XCTest 134 个测试、`ReminderParserTests` 38 个测试和 Release 通用构建检查已通过。下一步需要在 iPhone 17 模拟器和至少一台真机上完成通知闭环人工验收。
