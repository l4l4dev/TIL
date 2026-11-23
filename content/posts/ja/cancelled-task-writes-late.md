---
title: 'Task を cancel した直後にデータを消すと、遅れて終わった処理が消したデータを書き戻した'
description: 'Task の cancel は、処理が止まるのを待たずに返る。cancel した直後に鍵のファイルを消すと、遅れて終わった処理が同じ鍵を書き戻した。cancel のあとに task.value を待ってから消すか、世代を lock の中で確かめてから書くと、戻らなかった。'
lang: ja
translationKey: cancelled-task-writes-late
publishDate: 2026-11-23
tags: ['Swift', 'Concurrency']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、端末のあいだでデータをそろえる同期を開発しています。この同期に、データを暗号化する鍵を端末から消す操作があります。消したはずの鍵が、あとから戻ることがありました。

鍵を書いていたのは、消す直前に cancel した Task でした。Task は cancel されたあとも最後まで進み、消したあとの場所に鍵を書いていました。同じ並びを小さなパッケージで作り、どう書けば戻らないかを確かめました。

## cancel した Task は、最後まで進んで鍵を書いた

仕事は「時間のかかる確認をしてから、鍵をファイルに書く」です。確認には、完了ハンドラで結果を返す API を `withCheckedContinuation` で包んだものを使いました。0.3 秒後に結果を返し、キャンセルには反応しません。

```swift
func slowCheck(delay: Double = 0.3) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            continuation.resume(returning: true)
        }
    }
}

static func unchecked(store: KeyStore, log: Log) async {
    log("job: slow check starts")
    _ = await slowCheck()
    log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
    store.write("secret-key")
    log("job: wrote the key")
}
```

この仕事を Task で始め、50 ミリ秒後に cancel して、すぐに鍵のファイルを消します。

```swift
let task = Task { await SaveJob.unchecked(store: store, log: log) }
try? await Task.sleep(for: .milliseconds(50))
task.cancel()
store.remove()
```

```
[+   1 ms] job: slow check starts
[+  51 ms] main: cancel(), then remove()
[+ 321 ms] job: slow check returned, Task.isCancelled = true
[+ 321 ms] job: wrote the key
[+ 321 ms] file after: "secret-key"
```

`cancel()` はすぐに返りました。Task の側では `Task.isCancelled` が `true` になっただけで、確認は 0.3 秒かけて終わり、そのあと鍵を書きました。消したファイルは、270 ミリ秒後に元の中身で戻っています。

## 書く直前に isCancelled を確かめても、確認と書き込みのあいだに消すと戻った

書く直前に `Task.isCancelled` を見て、cancel されていれば書かない形にしました。

```swift
_ = await slowCheck()
guard !Task.isCancelled else {
    log("job: cancelled, not writing")
    return
}
store.write("secret-key")
```

同じ流れで試すと、鍵は戻りませんでした。

```
[+   0 ms] job: slow check starts
[+  55 ms] main: cancel(), then remove()
[+ 320 ms] job: slow check returned, Task.isCancelled = true
[+ 320 ms] job: cancelled, not writing
[+ 320 ms] file after: (absent)
```

ただし、`guard` と `store.write` は別の行です。`guard` で cancel されていないと確かめたあと、書く前に cancel と消去が入る並びを作りました。タイミングに頼らないよう、`guard` の直後に外からの合図を待つ処理を入れています。

```
[+   0 ms] job: slow check starts
[+ 320 ms] job: slow check returned, Task.isCancelled = false
[+ 321 ms] job: isCancelled was false, about to write
[+ 321 ms] main: job is between the check and the write; cancel(), then remove()
[+ 327 ms] job: wrote the key (Task.isCancelled = true now)
[+ 327 ms] file after: "secret-key"
```

鍵は戻りました。合図を待つ処理を入れない実際のコードで、この並びがどのくらい起きるかは測っていません。`guard` と書き込みのあいだには何もないので、起きにくいとは考えています。それでも、cancel する側と書く側が別のスレッドで動くなら、起きないとは言えません。

## cancel のあとに task.value を待ってから消すと、戻らなかった

最初の、`Task.isCancelled` を見ない仕事に戻します。cancel のあと、`await task.value` で仕事が終わるのを待ってから消しました。

```swift
task.cancel()
await task.value
store.remove()
```

```
[+   1 ms] job: slow check starts
[+  54 ms] main: cancel(), await task.value
[+ 323 ms] job: slow check returned, Task.isCancelled = true
[+ 324 ms] job: wrote the key
[+ 324 ms] main: task finished after waiting 269 ms, now remove()
[+ 429 ms] file after: (absent)
```

仕事は鍵を書きましたが、消すのはそのあとなので、ファイルは消えたままです。待った時間は 269 ミリ秒でした。確認が終わるまでの残りの時間と同じだけ、消す側が待つことになります。

## 待てない場面では、世代を lock の中で確かめてから書いた

消す側が async でない関数で、`await` を書けないこともあります。この場合は、鍵の置き場に世代の番号を持たせました。消す側は、1 つの lock の中で世代を 1 つ進めてから消します。書く側は、Task を作る前に世代を読み、仕事に持たせます。書くときは、同じ lock の中で世代が変わっていないのを確かめてから書きます。

```swift
final class GuardedKeyStore: Sendable {
    private let store: KeyStore
    private let generation = Mutex(0)

    var currentGeneration: Int { generation.withLock { $0 } }

    func invalidateAndRemove() {
        generation.withLock { value in
            value += 1
            store.remove()
        }
    }

    func write(_ key: String, ifGeneration expected: Int) -> Bool {
        generation.withLock { value in
            guard value == expected else { return false }
            store.write(key)
            return true
        }
    }
}
```

仕事は `Task.isCancelled` を見ず、持たされた世代だけで決めます。

```swift
let generation = store.currentGeneration
let task = Task {
    await SaveJob.gated(store: store, generation: generation, log: log)
}
```

```swift
// SaveJob.gated
_ = await slowCheck()
let wrote = store.write("secret-key", ifGeneration: generation)
log(wrote ? "job: wrote the key" : "job: generation changed, did not write")
```

さきほど鍵が戻ったのと同じ並びで試しました。確認が終わって書く直前に、cancel と消去を入れています。

```
[+   0 ms] job: started with generation 0, Task.isCancelled = false
[+ 319 ms] job: slow check returned, Task.isCancelled = false
[+ 319 ms] main: job is about to write; cancel(), then invalidateAndRemove() (no await)
[+ 320 ms] job: generation changed, did not write
[+ 320 ms] file after: (absent)
```

鍵は戻りませんでした。世代の確認と書き込みが 1 つの lock の中にあり、消去も同じ lock を取るので、あいだに消去が入りません。

## 世代を Task の中で読むと、Task が動き出す前の消去のあとで鍵が戻った

世代を読む場所は、Task を作る前にしています。はじめは Task の中の最初の行で読んでいて、この記事のレビューで、それでは遅い並びがあると指摘を受けました。Task を作ってから中の処理が動き出すまでのあいだに、cancel と消去が済む並びです。仕事の最初に合図を待つ処理を入れて、この並びを作りました。

```
[+   0 ms] main: job has not started yet; cancel(), then invalidateAndRemove() (no await)
[+   0 ms] job: started with generation 1, Task.isCancelled = true
[+ 319 ms] job: slow check returned, Task.isCancelled = true
[+ 320 ms] job: wrote the key
[+ 320 ms] file after: "secret-key"
```

仕事は、消去で進んだあとの世代 1 を読みました。書くときの世代も 1 なので、世代は変わっていないと判定され、鍵を書いています。同じ並びで、Task を作る前に世代を読むと、鍵は戻りませんでした。

```
[+   0 ms] main: read generation 0 before creating the task
[+   0 ms] main: job has not started yet; cancel(), then invalidateAndRemove() (no await)
[+   0 ms] job: started with generation 0, Task.isCancelled = true
[+ 319 ms] job: slow check returned, Task.isCancelled = true
[+ 319 ms] job: generation changed, did not write
[+ 319 ms] file after: (absent)
```

仕事が持っているのは消去の前の世代 0 なので、書き込みは断られました。

## FirnPlanner では、待てる所は待ち、待てない所は世代で防いだ

FirnPlanner では、2 つとも使いました。

同期のデータを消す操作と、同期をやり直す操作は async です。cancel した仕事を覚えておき、すべて終わるのを待ってから鍵を消すようにしました。cancel した仕事が複数あることもあるので、cancel した順につないで待ちます。

同期が使えないときに鍵を消す操作は、待たずにすぐ消します。こちらは、鍵を書く所に世代の確認を入れました。世代は、仕事を頼むときに Task の外で読んで持たせています。

## まとめ

- `Task.cancel()` は、処理が止まるのを待たずに返る。キャンセルに反応しない待ちの中にいる仕事は、そのまま最後まで進んだ
- cancel した直後に消したファイルは、遅れて終わった仕事が書き戻した
- 書く直前に `Task.isCancelled` を見ると、今回の流れでは戻らなかった。確認と書き込みのあいだに消去が入る並びでは戻った
- cancel のあとに `await task.value` で待ってから消すと、戻らなかった
- 待てない場面では、消去で世代を進め、書く側が同じ lock の中で世代を確かめると、戻らなかった
- 世代は Task を作る前に読む。Task の中で読むと、Task が動き出す前に消去が済んだとき、新しい世代を読んで鍵を書いた

試したパッケージは [samples/cancelled-task-writes-late](https://github.com/l4l4dev/TIL/tree/main/samples/cancelled-task-writes-late) に置きました。`swift run cancel-demo` で、ここに載せたのと同じ並びのログが出ます。時刻の数字は、流すたびに少し変わります。3 回流して、鍵が戻るかどうかは 3 回とも同じでした。

確かめた環境: Xcode 27.3 beta 2 (27C5035i)、Swift 6.4.4、macOS 27.3、`swift run` で実行。
