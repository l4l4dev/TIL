---
title: 'Cache-Control の無いレスポンスは、Last-Modified があると URLSession.shared がキャッシュから返し続ける'
description: 'サーバーが Last-Modified だけを付けて Cache-Control を付けないと、URLSession.shared は 2 回目以降のリクエストをサーバーに送らず、キャッシュしたレスポンスを返した。返し続ける長さは Last-Modified からの経過時間の 1 割弱だった。アプリではキャッシュを持たないセッションにし、サーバーでは no-store を付けて止めた。'
lang: ja
translationKey: urlsession-heuristic-cache
publishDate: 2026-11-20
tags: ['Swift', 'URLSession', 'iOS', 'macOS']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、端末のあいだでデータを同期する機能を開発しています。その開発中に、サーバーのレスポンスに新しいヘッダーを追加したところ、アプリがそのヘッダーを読めずにエラーで止まりました。アプリは `URLSession.shared` で通信していて、以前に受け取ったレスポンスをキャッシュから返していました。サーバーのレスポンスには `Last-Modified` があり、`Cache-Control` はありませんでした。

同じことが小さい例でも起きるかを確かめました。

## Last-Modified だけのレスポンスは、2 回目からサーバーに届かなかった

サーバーは、GET のたびに「それまでに受けたリクエストの数」を本文で返します。ヘッダーは `Last-Modified` (30 日前の日時) だけで、`Cache-Control` も `Expires` も付けません。

```python
body = f"answer #{count}".encode()
self.send_response(200)
self.send_header("Content-Type", "text/plain")
self.send_header("Content-Length", str(len(body)))
self.send_header("Last-Modified", LAST_MODIFIED)
self.end_headers()
self.wfile.write(body)
```

クライアントは、同じ URL を 1 秒おきに 3 回取りに行きます。

```swift
for attempt in 1...attempts {
    let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
    print("attempt \(attempt) got \"\(String(decoding: data, as: UTF8.self))\"")
    try await Task.sleep(for: .seconds(1))
}
```

サーバーのヘッダーとクライアントの設定を変えて流した結果です。

| サーバーのレスポンス | クライアント | 受け取った本文 | サーバーに届いた数 |
|---|---|---|---|
| `Last-Modified` だけ | `URLSession.shared` | #1、#1、#1 | **1** |
| `Last-Modified` だけ | キャッシュを持たないセッション | #1、#2、#3 | 3 |
| `Last-Modified` だけ | `URLSession.shared`、リクエストに `reloadIgnoringLocalCacheData` | #1、#2、#3 | 3 |
| `Last-Modified` と `Cache-Control: no-store` | `URLSession.shared` | #1、#2、#3 | 3 |
| どちらも無し | `URLSession.shared` | #1、#2、#3 | 3 |

1 行目では、2 回目と 3 回目のリクエストがサーバーに届いていません。`If-Modified-Since` を付けた問い合わせも来ませんでした。`Last-Modified` を外すと毎回届いたので、キャッシュから返すかどうかは `Last-Modified` の有無で変わっています。

## キャッシュから返す長さは、Last-Modified からの経過時間の 1 割弱だった

`Last-Modified` を今に近づけて、1 秒おきに 14 回取りに行きました。

| `Last-Modified` | サーバーに届いた時刻 (開始からの秒) |
|---|---|
| 40 秒前 | 0.0、3.1、6.2、9.3、13.5 |
| 100 秒前 | 0.0、9.2 |

40 秒前ではおよそ 3 秒、100 秒前ではおよそ 9 秒のあいだ、キャッシュから返しました。1 秒おきにしか見ていないので、切り替わりの時刻には最大 1 秒の幅があります。

HTTP のキャッシュの仕様 ([RFC 9111 の 4.2.2](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2.2)) は、期限の指定が無いレスポンスについて、キャッシュが `Last-Modified` などから期限を見積もってよいとしています。見積もりの例に挙がっているのが、`Last-Modified` からの経過時間の 10% です。測った値はそれより少し短いものの、近い割合でした。

同じ割合なら、30 日前の `Last-Modified` では 3 日近くキャッシュから返すことになります。ここは計算で、3 日のあいだ測ったわけではありません。実験は 1 回の起動の中だけで、起動をまたいでも続くかも測っていません。

## アプリとサーバーの両方で止めた

アプリでは、キャッシュを持たないセッションを作って使うようにしました。

```swift
let configuration = URLSessionConfiguration.default
configuration.urlCache = nil
configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
let session = URLSession(configuration: configuration)
```

セッションを外から渡せる作りにしているので、リクエストにも `cachePolicy = .reloadIgnoringLocalCacheData` を入れています。表の 3 行目のとおり、`URLSession.shared` を渡されてもサーバーに届きます。

サーバーでは、エラーを含むすべてのレスポンスに `Cache-Control: no-store` を付けました。アプリを直しても、直す前のビルドと、あいだに入るプロキシの動きは変わらないためです。表の 4 行目のとおり、`no-store` があれば `URLSession.shared` のままでも毎回届きます。

## まとめ

- `Last-Modified` があって `Cache-Control` が無いレスポンスを、`URLSession.shared` はキャッシュから返すことがある。そのあいだ、リクエストはサーバーに届かない
- 毎回サーバーの今の状態を読みたい API では、サーバーが `Cache-Control: no-store` を返す
- クライアントでも、`urlCache = nil` のセッションか、リクエストの `reloadIgnoringLocalCacheData` で止められる

試したスクリプトは [samples/urlsession-heuristic-cache](https://github.com/l4l4dev/TIL/tree/main/samples/urlsession-heuristic-cache) に置きました。`./run.sh plain shared` が表の 1 行目、`./run.sh plain shared 14 40` が 40 秒前の実験です。

確かめた環境: Xcode 27.3 beta 2 (27C5035i)、Swift 6.4.4、macOS 27.3。
