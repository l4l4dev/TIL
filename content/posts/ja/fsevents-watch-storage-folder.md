---
title: 'ファイル単位の監視は原子的な置換のあと黙る。フォルダ全体は FSEvents で 1 本だけ見る'
description: 'ユーザーが選んだフォルダの Markdown を正として持つ macOS アプリで、外部の変更をどう検知するか。ファイル単位の DispatchSource は原子的な置換のあと通知が止まり、ディレクトリ単位は追記を拾えなかった。小さな実験の出力と、FSEvents をルートに 1 本だけ張る実装の要点。'
lang: ja
translationKey: fsevents-watch-storage-folder
publishDate: 2026-10-01
tags: ['macOS', 'Swift', 'FSEvents']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、ユーザーが選んだフォルダの Markdown ファイルを正として持っています。日ごとの予定と受信箱が、そのフォルダの下にある普通のファイルです。外のエディタや同期ツールでファイルが変わったら、アプリは読み直さなければいけません。

この「フォルダの変更を知る」部分を、FSEvents で行っています。最初に思いつくのは DispatchSource ですが、使っていません。理由を、小さな実験で確かめた範囲で書きます。

## ファイル単位の DispatchSource は、置換の 1 回目のあと通知が来なくなった

アプリの保存は、一時ファイルに書いてから置き換える原子的な書き込みです。実装のコメントによると、これが DispatchSource を避けた理由です。置換の 1 回目で監視対象の inode が消えて、以後の書き込みが届かなくなる、という説明でした。

本当にそうなるのかを、別のスクリプトで確かめました。1 つのファイルに対して、次の 3 つを同時に張っています。

- ファイルを開いた記述子に対する `DispatchSource.makeFileSystemObjectSource` (ファイル単位)
- 親ディレクトリに対する同じ DispatchSource (ディレクトリ単位)
- ディレクトリに対する FSEvents (`kFSEventStreamCreateFlagFileEvents` 付き)

そのうえで、追記、`write(to:atomically: true)` による置換 3 回、置換後の追記を順に行い、各操作のあとに届いた通知の数を数えます。FSEvents は、対象のファイル名の通知だけを数えました。

```text
1 append in place      : file-source=1 dir-source=0 fsevents(note.md)=1
2 atomic replace #1    : file-source=1 dir-source=2 fsevents(note.md)=2
3 atomic replace #2    : file-source=0 dir-source=2 fsevents(note.md)=2
4 atomic replace #3    : file-source=0 dir-source=2 fsevents(note.md)=2
5 append after replace : file-source=0 dir-source=0 fsevents(note.md)=1
```

macOS 27.2 で、3 回実行して同じ結果でした。読み取れることは次の 3 点です。

- ファイル単位の DispatchSource は、1 回目の置換で通知を 1 つ受けたあと、2 回目以降の置換と置換後の追記を受けていません。記述子が古いほうのファイルに付いたままだから、と考えられますが、inode が変わったことまでは確かめていません。
- ディレクトリ単位の DispatchSource は、置換は拾いましたが、追記は拾いませんでした (1 行目の `dir-source=0`)。
- FSEvents は、追記も、3 回の置換も、置換後の追記も受け取り続けました。

実験で言えるのは、この 3 通りの操作で届いた通知の数までです。他の同期ツールがどの順にファイルを書くかは見ていません。

## 置換 1 回で同じファイルの通知が 2 回来る

もう 1 つ、表から分かることがあります。原子的な置換 1 回で、FSEvents からは同じファイル名の通知が 2 回届いています。一時ファイルの作成と、置き換えの 2 つが別々に見えるためだと考えています。

読み直す側から見ると、2 回とも同じ読み直しになります。そこで実装では、1 回のコールバックの中で、同じ内容の通知を 1 つに畳んでいます。たとえば「2026-10-01 の日」の通知が 2 つ並んでいたら、1 つしか流しません。

## FSEvents はルートに 1 本だけ張る

実装のコメントでは、FSEvents のストリームは保存先のルートに 1 本だけ張るとしています。日ごとのファイルも受信箱も同じフォルダの下にあるので、表示している日が変わっても張り替えは要りません。どのファイルの通知かは、パスから `StorageChange` に直す別の部品が振り分けます。

その部品は、ファイルシステムに触らず、パスの文字列だけを見ます。確認した範囲では、次のものを除いています。

- 保存先の外のパス
- 原子的な書き込みの一時ファイル (名前と拡張子の形で弾く)
- 日ごとのファイルの置き場所に合わない名前、および年・月のフォルダと日付が食い違うファイル

また、監視から届くパスはシンボリックリンクが解決された形で来ます。ルートの側も同じ形に揃えてから比べないと、`/var` と `/private/var` の違いで取りこぼします。実在しなくなったファイル (削除の通知) では解決が `/private` を落とさないので、両側に同じ後始末をかけています。これもコードのコメントにある理由です。

## 個々のファイルを特定できない通知は、全体の読み直しにする

FSEvents は、イベントが多すぎるときに、個別のパスを返さず、「この下を全部見直して」というフラグ (`MustScanSubDirs`) を付けて返すことがあります。ボリュームの付け外しや、見ているフォルダ自体の移動も、同じように個々のファイルが分かりません。

実装では、`MustScanSubDirs`、`RootChanged`、`Mount`、`Unmount` のいずれかが立っていたら、「全体を読み直す」という通知 (`needsFullRecheck`) にしています。受け手は、関心のあるファイルをすべて見直します。ルートの移動を拾うために、ストリームには `WatchRoot` も付けています。

## コールバックの寿命を、監視の本体と分ける

FSEvents のコールバックは、自前のキューで動きます。監視の本体 (`stop()` を呼ぶと解放される側) が消えたあとに、遅れて 1 回届くことがあり得ます。

そこで、通知を配る側を別の小さなクラス (実装では `Sink` と呼んでいます) に分けています。コールバックが触るのは Sink だけで、購読している `AsyncStream` の継続 (continuation) を持つのも Sink です。

- Sink は、`info` ポインタ経由でストリームに保持させます。保持の回数は自分で 1 回だけ数え、解放は FSEvents 側の release コールバックに任せます。コメントによると、FSEvents に retain も任せると、実装が retain を呼ぶかどうかで解放の回数が変わるためです。
- `stop()` は二度呼んでも副作用がありません。ストリームを止めて解放し、Sink を終了済みにします。終了済みの Sink に後から購読しに来た側は、すぐ終了を受け取ります。

この部分は FSEvents のコールバックの扱いというより、C の API に Swift のオブジェクトを渡すときの寿命の話です。

## 監視を始められなくても、保存は壊れない

ストリームが作れないとき (FSEvents が使えないボリューム等) は、通知が流れないだけです。アプリは、保存のときに読み込んだ時点の内容と照らし合わせる仕組みを別に持っていて、そちらは影響を受けません。外の変更を読み直すのが遅れても、外で変わったファイルを保存で上書きしない仕組みはそのまま働きます。

## 通知の間隔は 0.1 秒で、静かなときの 1 発目は待たない

通知のまとめ待ちは 0.1 秒で、`NoDefer` と組み合わせています。このフラグがあると、静かな状態からの 1 発目はすぐ届き、続けて起きた分だけが 0.1 秒の間隔でまとまります。0.1 秒という値を選んだ理由はコードに書かれていないので、ここでは触れません。

## 再現した実験のコード

実験は、およそ次のような形です (DispatchSource と FSEvents の部分だけ抜いています)。

```swift
// ファイル単位: 開いた記述子に対する DispatchSource
let fd = open(file.path, O_EVTONLY)
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend], queue: .global())
source.setEventHandler { /* 通知の数を 1 つ増やす */ }
source.resume()

// FSEvents: ディレクトリに 1 本。ファイル単位のイベントを受ける
let stream = FSEventStreamCreate(
    kCFAllocatorDefault, callback, &context, [dir.path] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1,
    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagUseCFTypes))
```

ファイルを見張りたいときでも、ファイルではなく置き場所のフォルダを FSEvents で見て、パスで振り分ける形のほうが、置換に強いと感じました。
