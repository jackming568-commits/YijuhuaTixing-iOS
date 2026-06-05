---
name: product-app-logo-preview
description: Use this skill when designing App Icon or logo previews for a product, app, SaaS tool, or mobile utility. It creates 3 distinct visual directions first, avoids replacing project assets prematurely, writes strong image-generation prompts, and validates icons at large and small sizes before implementation.
---

# Product App Logo Preview

Use this skill to turn a product idea into 3 App Icon / logo preview directions before touching production assets.

## Workflow

1. Clarify the product promise in one sentence.
2. Extract 3-5 visual keywords from the product behavior.
3. Create 3 distinct icon directions:
   - Direct metaphor: the most obvious product action.
   - Differentiator: the newest or strongest feature.
   - Efficiency/result: the outcome users want.
4. Keep all directions text-free unless the user explicitly asks for a wordmark.
5. Generate or provide prompts for 1024x1024 previews.
6. Do not replace `Assets.xcassets`, `AppIcon.appiconset`, favicon, or brand files until the user chooses one direction.
7. After selection, refine only the chosen direction and then plan asset replacement.

## Prompt Template

```text
Use case: logo-brand
Asset type: iOS App Icon preview, 1024x1024
Primary request: Create a clean rounded app icon for <product category>. The mark combines <symbol 1>, <symbol 2>, and <symbol 3> to express "<product promise>".
Style: rounded geometric, vector-friendly, high recognition at small sizes, no text, no watermark, no complex shadow.
Palette: <primary color>, <secondary color>, <confirmation/accent color>, white main symbol.
Composition: centered symbol, large readable shapes, generous safe area for iOS rounded-corner crop.
Background: soft gradient or clean solid background consistent with the product UI.
Avoid: letters, tiny details, realistic clutter, busy shadows, unreadable thin lines, watermarks.
```

## Three-Direction Pattern

For a natural-language reminder app, use:

- A: speech bubble + checkmark + clock ticks, expressing "one sentence becomes a reminder".
- B: rounded bell + voice waves + checked node, expressing voice/natural-language input and reliable reminders.
- C: short sentence line + forward arrow + calendar dots, expressing fast conversion from input to scheduled action.

For other products, keep the same structure but swap symbols to match the product:

- Input symbol: chat bubble, cursor, microphone, form, scan frame.
- Transformation symbol: arrow, spark, bridge, flow, node.
- Output symbol: check, calendar, chart, card, document, shield, bell.

## Validation

Check every preview at:

- 1024px: polished and memorable.
- 180px: main shape still clear.
- 60px: not muddy or overly detailed.

Also check:

- No text or accidental letters.
- Strong safe area for rounded App Icon crop.
- Consistent with existing app colors and UI tone.
- The icon communicates function, result, or category without explanation.

## Environment Rule

If image generation is unavailable or no image tool is exposed:

- Do not stall.
- Provide the 3 finished prompts instead.
- Do not use a CLI fallback that requires `OPENAI_API_KEY` unless the user explicitly asks for it.

## Handoff

When finished, report:

- The 3 directions.
- The final prompts.
- Whether previews were generated or prompts only.
- Confirmation that no production app icon assets were changed.
