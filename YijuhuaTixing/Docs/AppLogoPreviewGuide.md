# 一句话提醒 App Logo 三版预览沉淀

日期：2026-06-05
适用项目：`一句话提醒` / 自然语言提醒类 App
目标：先做 3 个 App Icon 预览方向，不替换工程资源，用户选定后再精修和接入。

## 核心表达

Logo 要表达“一句成事”：用户说出或输入一句话，App 自动转成明确时间和可执行提醒。

视觉气质：

- 清爽圆润，符合 iOS App Icon 语境。
- 延续 App 当前的 iOS 蓝。
- 加入薄荷绿确认色，表达完成、可靠、确认。
- 不放文字，保证小尺寸也能识别。

## 三版方向

### A：对话气泡 + 对勾 + 时钟刻度

表达重点：一句话变提醒。

适合做默认首选，因为信息最直接：对话气泡代表输入，对勾代表确认，时钟刻度代表提醒时间。

生成提示词：

```text
Use case: logo-brand
Asset type: iOS App Icon preview, 1024x1024
Primary request: Create a clean rounded iOS app icon for a natural-language reminder app. The mark combines a speech bubble, a checkmark, and subtle clock tick marks to express "one sentence becomes a reminder".
Style: rounded geometric, vector-friendly, high recognition at small sizes, no text, no watermark, no complex shadow.
Palette: bright iOS blue #0A84FF, cyan blue #22C7E8, mint green #34C759, white main symbol.
Composition: centered white speech bubble as the main shape, mint green checkmark inside, subtle clock tick marks integrated around or behind the bubble. Generous safe area for iOS rounded-corner crop.
Background: soft light blue to cyan gradient, clean and modern.
Avoid: letters, Chinese characters, realistic objects, busy details, tiny unreadable marks, dark heavy shadows.
```

### B：圆角铃铛 + 语音波纹 + 勾选节点

表达重点：语音 / 自然语言输入和可靠提醒。

适合在语音输入成为核心卖点时选择。铃铛代表提醒，语音波纹代表说一句，勾选节点代表识别成功。

生成提示词：

```text
Use case: logo-brand
Asset type: iOS App Icon preview, 1024x1024
Primary request: Create a clean rounded iOS app icon for a reminder app with voice and natural-language input. The mark combines a rounded bell, voice wave lines, and a small checked node to express reliable spoken reminders.
Style: rounded geometric, friendly, crisp, vector-friendly, high recognition at 180px and 60px, no text, no watermark.
Palette: bright iOS blue #0A84FF, cyan blue #22C7E8, mint green #34C759, white main symbol.
Composition: centered white rounded bell, two or three simple voice wave arcs on one side, one mint green check node near the bell. Keep all details large and readable.
Background: soft light blue to cyan gradient, clean iOS feel.
Avoid: alarm clock realism, microphone realism, complex gradients inside the symbol, thin fragile lines, letters, Chinese characters.
```

### C：一句话短横线 + 向前箭头 + 日历圆点

表达重点：高效执行和任务流转。

适合更偏效率工具的品牌方向。短横线代表一句话，箭头代表转换和推进，日历圆点代表进入日程/任务。

生成提示词：

```text
Use case: logo-brand
Asset type: iOS App Icon preview, 1024x1024
Primary request: Create a clean rounded iOS app icon for a productivity reminder app. The mark combines one short sentence line, a forward arrow, and calendar dots to express fast conversion from input to scheduled action.
Style: rounded geometric, minimal, energetic, vector-friendly, high recognition at small sizes, no text, no watermark.
Palette: bright iOS blue #0A84FF, cyan blue #22C7E8, mint green #34C759, white main symbol.
Composition: centered white short horizontal line flowing into a forward arrow, ending near two or three mint green calendar dots. The shapes should feel like a simple task flow.
Background: soft light blue to cyan gradient, clean and light.
Avoid: dense calendar grid, too many dots, text-like marks, dark shadows, realistic stationery, letters, Chinese characters.
```

## 统一生成要求

- 输出尺寸：`1024x1024`
- 不放文字，不放水印。
- 主体居中，保留 iOS 圆角裁切安全区。
- 主形状尽量粗、圆、少细节。
- 大图、180px、60px 都要能看出主体。
- 只做预览，不直接替换 `Assets.xcassets`。

## 检查标准

- 1024 大图：是否干净、有记忆点。
- 180 小图：是否还能看出主体符号。
- 60 小图：是否不糊成一团。
- 功能表达：是否能看出提醒、时间、确认、效率。
- 风格一致：是否贴近当前 App 的蓝色按钮、绿色完成态、圆润 UI。
- 安全区：圆角裁切后主体不贴边、不丢关键信息。

## 当前环境注意

如果当前 Codex 环境没有直接暴露内置 `image_gen` 工具，不要卡在图片生成步骤。

处理方式：

- 先输出三版高质量提示词。
- 不使用需要额外 `OPENAI_API_KEY` 的 CLI fallback。
- 等可用图片生成环境或用户指定工具后，再按提示词生成预览。

## 后续接入流程

1. 用户从 A / B / C 中选一个方向。
2. 对选中的方向做 1-2 轮精修。
3. 生成 AppIcon 所需尺寸。
4. 备份当前 `Assets.xcassets/AppIcon.appiconset`。
5. 替换工程图标资源。
6. 用 Xcode 真机检查桌面图标、小组件/设置里显示是否清晰。
