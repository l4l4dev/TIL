# XCUIHinge sample

記事「XCUIHinge でヒンジの角度を UI テストから動かせる」で使ったプロジェクトです。
The project used in the post "XCUIHinge moves the hinge from a UI test".

## 必要なもの / Requirements

- Xcode 27.3 beta 1 以降 / Xcode 27.3 beta 1 or later
- iOS 27.3 シミュレータの iPhone Duo / iPhone Duo on the iOS 27.3 simulator

`HingeLab.xcodeproj` は XcodeGen 2.45.4 で `project.yml` から生成したものです。XcodeGen がなくても、そのまま開けます。
`HingeLab.xcodeproj` was generated from `project.yml` with XcodeGen 2.45.4. You can open it without XcodeGen.

## 流し方 / Run

```sh
xcodebuild test -project HingeLab.xcodeproj -scheme HingeLab \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.3'
```

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `App/HingeLabApp.swift` | 画面の幅と size class を表示するだけのアプリ / An app that only shows the width and size class |
| `UITests/HingeArticleTests.swift` | 記事の XCTest の例 / The XCTest example in the post |
| `SwiftTestingUITests/HingeSwiftTests.swift` | 記事の Swift Testing の例 / The Swift Testing example in the post |
| `UITests/HingeSettleTests.swift` | 記事の表の値を取ったテスト。表示が 2 秒変わらなくなるまで待って読む / The test behind the tables in the post. It reads after the screen has not changed for 2 seconds |
| `UITests/HingeSweepTests.swift` | `sleep(1)` だけ待って 15° ずつ動かしたテストと、`hinge` が `nil` かを出すテスト / Moves the hinge in 15° steps with only `sleep(1)`, and prints whether `hinge` is `nil` |

結果はテストのログに `SETTLE` や `SWEEP` で始まる行として出ます。
Results appear in the test log as lines starting with `SETTLE` or `SWEEP`.
