---
title: 'Swift Testing の .serialized はテストを 1 つずつ流すが、同じスレッドで動くとは限らない。.timeLimit を超えても止まらないテストもある'
description: 'Swift Testing のテストは何も付けなければ同時に走る。.serialized を付けると 1 つずつ流れるが、スレッドはテストごとに変わった。.timeLimit は分でしか書けず、超えるとタスクがキャンセルされて失敗する。ただし、スレッドを止めて待つテストは、超えた後も最後まで動き続けた。'
lang: ja
translationKey: swift-testing-serialized-timelimit
publishDate: 2026-11-06
tags: ['Swift', 'Testing']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、同じ状態を触るテストの Suite に `.serialized` を付けています。何も付けないとどう走るのか、`.serialized` と `.timeLimit` で何が変わるのかを、小さなパッケージで確かめました。

## 何も付けないと、テストは同時に走る

Swift Testing は、何も指定しなければテストを同時に走らせます。1 つの数を共有する 3 つのテストを用意し、それぞれが 1,000 回「読んで、`await` を挟んで、1 足して書き戻す」ようにしました。

```swift
for _ in 0..<1000 {
    let value = counter.read()
    await Task.yield()
    counter.write(value + 1)
}
```

1 つずつ流れれば、最後は 3,000 になります。何も付けずに 3 回流すと、3 つのテストが書き終えたときの値はどれも 1,011〜1,056 でした。ほかのテストが読んでから書き戻すまでのあいだに書いた分が、上書きされて消えています。3 つのテストは同じ時刻に始まり、1 秒の待ちを挟んで同じ時刻に終わっていました。

`swift test --help` では、`--parallel/--no-parallel` の既定は `--no-parallel` と出ます。それでも、何も指定しない `swift test` では同時に走りました。`--no-parallel` をはっきり付けたときだけ、テストは 1 つずつ流れて 3,000 になりました。

## .serialized は 1 つずつ流すが、スレッドは揃わない

同じ 3 つのテストを、`.serialized` を付けた Suite に入れました。

```swift
@Suite(.serialized) struct Serialized {
    @Test func a() async throws { try await work("serial.a"); await bump(serialCounter, label: "serial.a") }
    @Test func b() async throws { try await work("serial.b"); await bump(serialCounter, label: "serial.b") }
    @Test func c() async throws { try await work("serial.c"); await bump(serialCounter, label: "serial.c") }
}
```

3 回とも、a が 0〜1 秒、b が 1〜2 秒、c が 2〜3 秒に流れ、値は 1,000、2,000、3,000 と増えました。順番は 3 回とも a、b、c でしたが、順番が決まっているとは書かれていないので、そこには頼らないほうがよいと考えています。

一方、動いたスレッドは揃いませんでした。テストの開始と終了で `pthread_mach_thread_np(pthread_self())` を記録すると、3 回のどれでも、テストごとにスレッドが違いました。1 つのテストの中でも、`await` の前後でスレッドが変わることがありました。`.serialized` が揃えるのは流れる順番で、スレッドではありません。同じスレッドで動くことを前提にしたテストは、`.serialized` を付けても、その前提どおりには動きません。

ほかに分かったことです。

- `.serialized` を付けた Suite の中のテスト同士は 1 つずつ流れるが、ほかの Suite のテストとは同時に走った
- `.serialized` を付けた Suite の中に入れた Suite のテストも、1 つずつ流れた
- 引数を渡すテスト (`@Test(arguments:)`) に `.serialized` を付けると、ケースが 1 つずつ流れた。付けないと、3 つのケースが同時に始まった

## .timeLimit は分でしか書けない

`.timeLimit` に渡す値は、`.minutes(_:)` でしか作れません。`.seconds(30)` と書くと、次のエラーでビルドが止まります。

```text
error: 'seconds' is unavailable: Time limit must be specified in minutes
```

ただし、`.minutes(0)` はビルドが通りました。3 秒待つテストに付けると、すぐに `Time limit was exceeded: 0.000 seconds` で失敗しました。分でしか書けないことはコンパイラが止めてくれますが、0 分は止めてくれません。

## 時間を超えると、タスクがキャンセルされて失敗する

90 秒待つテストに `.timeLimit(.minutes(1))` を付けると、待っていた `Task.sleep` が `CancellationError` を投げ、テストは失敗しました。

```swift
@Test(.timeLimit(.minutes(1))) func sleepsPastLimit() async throws {
    try await Task.sleep(for: .seconds(90))
}
```

出力には `Time limit was exceeded: 60.000 seconds` とありました。ただし、失敗が出たのは開始から約 64 秒後でした。4 秒の差がどこから来るのかは確かめていません。

Suite とテストの両方に付けたときや、引数を渡すテストでは、次のようになりました。3 回流して、どれも同じ結果でした。

| 試したこと | 付けた制限 | 結果 |
|---|---|---|
| 90 秒待つテスト | Suite に 1 分、テストに 3 分 | 約 64 秒で失敗 |
| 90 秒待つテスト | Suite に 3 分、テストに 1 分 | 約 64 秒で失敗 |
| 40 秒待つテスト 2 つを 1 つずつ流す | Suite に 1 分 | どちらも成功 (合わせて約 85 秒) |
| 40 秒待つケース 2 つを 1 つずつ流す | テストに 1 分 | 成功 (合わせて約 85 秒) |

どちらに付けても、短いほうの制限で失敗しました。Suite に付けた制限は Suite 全体の合計ではなく、中のテスト 1 つずつにかかります。引数を渡すテストでも、ケース 1 つずつにかかります。これは公式ドキュメントの説明と同じ結果でした。

## スレッドを止めて待つテストは、時間を超えても止まらない

Swift のタスクのキャンセルは、キャンセルされたかどうかをコードの側で確かめて止まる仕組みです。`Task.sleep` は、キャンセルされるとすぐに `CancellationError` を投げます。そこで、`Task.sleep` の代わりに `Thread.sleep(forTimeInterval: 90)` でスレッドごと止めるテストにも、`.timeLimit(.minutes(1))` を付けました。

時間を超えたことは、ほかのテストと同じころに記録されました。それでもテストは 90 秒の待ちを最後まで続け、失敗したのは開始から約 90 秒後でした。テスト全体の実行も、このテストが終わるまで終わりませんでした。`.timeLimit` は、キャンセルに応えないコードを止めてはくれません。

## まとめ

- 何も付けないと、テストは同時に走る。同じ状態を触るテストは、値が上書きされて壊れる
- `.serialized` は、テストを 1 つずつ流す。ただし、スレッドは揃わない
- `.timeLimit` は分でしか書けない。超えるとタスクがキャンセルされて失敗するが、スレッドを止めて待つコードは最後まで動き続ける

試したパッケージは [samples/swift-testing-traits](https://github.com/l4l4dev/TIL/tree/main/samples/swift-testing-traits) に置きました。`swift test --filter ParallelTests` で同時に走るテストと `.serialized` を、`swift test --filter TimeLimitTests` で `.timeLimit` を試せます。`TimeLimitTests` はわざと失敗するテストを含み、終わるまで約 90 秒かかります。

確かめた環境は次のとおりです。

- Xcode 27.2 (27B52)
- Swift 6.4.2
- macOS 27.2
- `swift test` で実行

参考にしたもの:

- [Limiting the running time of tests](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/LimitingExecutionTime.md) (Swift Testing の公式ドキュメント)
- [Using Traits to annotate and customize test behavior](https://www.avanderlee.com/swift-testing/using-traits-to-annotate-and-customize-test-behavior/) (SwiftLee)
- [How to set a time limit for concurrent tests](https://www.hackingwithswift.com/quick-start/concurrency/how-to-set-a-time-limit-for-concurrent-tests) (Hacking with Swift)
- [SwiftTestingのparameterizedテストとTraitsの書き方](https://qiita.com/Hilary02/items/089f0d252f56ad441c35) (Qiita)
- [Learnings About Swift Testing](https://engineering.mercari.com/en/blog/entry/20241212-learnings-about-swift-testing/) (Mercari Engineering)
