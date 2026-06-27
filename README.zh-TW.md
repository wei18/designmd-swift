# designmd-swift

[English](README.md) · **繁體中文**

[![CI](https://github.com/wei18/designmd-swift/actions/workflows/design-lint.yml/badge.svg)](https://github.com/wei18/designmd-swift/actions/workflows/design-lint.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg)](#)

[`@google/design.md`](https://github.com/google-labs-code/design.md) 的 Swift 移植版——
一個針對 **DESIGN.md** 格式的 linter、diff 與匯出器。DESIGN.md 是「給 coding agent 讀的設計系統
規格」：機器可讀的 token 加上人類可讀的 prose。本版本為 **UIKit / SwiftUI 開發流程**打造：在 CI 用
`designmd lint` 守門、用 `diff` 抓回歸，並生成原生的 `Theme.swift` + Asset Catalog（取代 Tailwind）。

純 Swift + Foundation，**macOS 與 Linux 皆可編譯執行**。不依賴 SwiftUI/UIKit——工具只是把 Apple
產物**以文字輸出**，不連結 UI framework。

## DESIGN.md 是什麼？

一個檔案，把**機器可讀的設計 token**（YAML frontmatter）和**人類可讀的設計理由**（markdown prose）
綁在一起。Token 給 agent 精確數值，prose 告訴它「為什麼」。它是一份持久、結構化的真相來源，讓
agent 產出的 UI 在不同畫面、不同 session 之間維持一致。

```markdown
---
name: Tide
colors:
  primary:   "#0B3D52"
  accent:    "#00A0C6"
typography:
  largeTitle: { fontFamily: SF Pro, fontSize: 34pt, fontWeight: "700" }
rounded:
  md: 12pt
---

## Overview
一個沉穩的潮汐 App，要像第一方 Apple App 一樣。
```

## 在 Apple 專案裡用它的價值

價值在**開發期 / agent 階段**，不是 app 的 runtime：

- **一致性**——給 AI agent 一份結構化的設計系統，產出的 SwiftUI 不會一個畫面一個樣。
- **單一真相來源**——`export` 重新生成型別安全的 `Theme.swift` + Asset Catalog；不用再手動同步散落
  各處的 `Color(hex:)` / `.padding(16)`。
- **CI 守門**——`lint` 在 WCAG 對比不足、缺 `primary`、引用壞掉等情況讓 build 失敗；`diff` 抓兩版之間
  的設計回歸。

## 安裝與編譯

```bash
git clone https://github.com/wei18/designmd-swift.git
cd designmd-swift
swift build -c release   # 執行檔在 .build/release/designmd
swift test               # 25 個測試
```

## CLI

```bash
designmd lint DESIGN.md                 # JSON findings + summary；有 error 回 exit 1
designmd lint DESIGN.md --format markdown
cat DESIGN.md | designmd lint -         # stdin
designmd diff OLD.md NEW.md             # token + finding 差異；有回歸回 exit 1

# Export——Apple 原生目標取代 Tailwind；保留 DTCG 供互通
designmd export DESIGN.md --format dtcg                          # W3C tokens.json → stdout
designmd export DESIGN.md --format swift  --out Theme.swift      # SwiftUI 主題
designmd export DESIGN.md --format asset-catalog --out Colors.xcassets

# Spec——方便把格式規格塞進 agent 的 prompt
designmd spec --rules
```

`swift` 產出強型別的 `Theme` enum（`Theme.Colors.primary`、`Theme.Spacing.md`、
`Theme.Typography.body`、`Theme.Radius.lg`）——顏色為 sRGB `Color` literal、尺寸為 `CGFloat` 點數、
字體為 `Font`（SF Mono → `.monospaced`、New York → `.serif`、SF Pro Rounded → `.rounded`，其他字族
→ `Font.custom`）。`asset-catalog` 為每個顏色 token 寫一個 `.colorset`，讓 `Color("on-surface")`
在 runtime 解析。

## 函式庫

```swift
import DesignMD

let report = lint(markdownString)
report.findings      // [Finding]
report.summary       // errors / warnings / infos
report.designSystem  // 完整解析的模型（colors、typography…）

let d = computeDiff(before: oldString, after: newString)   // d.regression: Bool
let theme = exportSwiftTheme(report.designSystem)          // Theme.swift 原始碼
let dtcg  = exportDTCG(report.designSystem).serialize()    // W3C tokens.json
```

## 範例

[`examples/Tide`](examples/Tide) 是一個完整、可編譯的範例：一份 `DESIGN.md`、生成的 `Theme.swift`
+ `Tide.xcassets`、一個使用它們的 SwiftUI `TideCardView`，還有一個零依賴的
[`prototype.html`](examples/Tide/prototype.html) 把 token 與 lint 成效視覺化（它甚至抓到一個真實的
WCAG 失敗——白字配 accent 色只有 3.07:1）。

## CI

[`.github/workflows/design-lint.yml`](.github/workflows/design-lint.yml) 會 build 工具、跑測試，
然後對 repo 內每個 `DESIGN.md` 跑 `designmd lint` 守門（用 GitHub 的 `::error file=…::` 行內標註）。
在 `swift:6.0` Linux container 上跑，含 SwiftPM build 快取。可用 `DESIGN_FILES` env 指定要 lint 的檔案。

## 與上游的一致性

parser、model、CSS 顏色運算（WCAG 亮度/對比）、`{path.to.token}` 解析（含循環/深度保護）、全部 9 條
lint 規則、diff 引擎、DTCG 匯出器與 `spec` 指令都是忠實移植。對上游 TypeScript CLI 驗證為
**byte-identical**：`lint`（12 fixtures）、`diff`（5 組）、`export --format dtcg`（7 fixtures）、
`spec`（規則表 + 規則 JSON）。共 25 個測試。

### 唯一刻意的差異：`pt` 單位

上游只接受 `px`/`rem`/`em`，其他一律標記為錯。本版本把 **`pt`（點）**加為一等公民的標準單位，讓
UIKit/SwiftUI 的設計系統不會被誤判；`px`/`rem`/`em` 仍保留相容。見 `SpecConfig.standardUnits`。

## 指令

| 指令 | 用途 |
|------|------|
| `lint`  | 驗證結構、引用、WCAG 對比（9 條規則）；有 error 回 exit 1 |
| `diff`  | 兩版之間的 token + finding 差異；有回歸回 exit 1 |
| `export`| `dtcg`（W3C tokens.json）· `swift`（Theme.swift）· `asset-catalog`（.xcassets） |
| `spec`  | 輸出格式規格 + 啟用中的規則表（markdown 或 json） |

## 授權與致謝

Apache-2.0（見 [LICENSE](LICENSE) 與 [NOTICE](NOTICE)）。移植自 Google Labs 的
[DESIGN.md](https://github.com/google-labs-code/design.md)；格式、規格模型、`{path.to.token}` 語法、
lint 語意與 prose-first 哲學皆屬上游，本專案以 Swift 為 Apple 平台重新實作。
