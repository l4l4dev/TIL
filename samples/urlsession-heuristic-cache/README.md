# URLSession heuristic cache sample

記事「Cache-Control の無いレスポンスは、Last-Modified があると URLSession.shared がキャッシュから返し続ける」で使ったスクリプトです。
The scripts used in the post "URLSession.shared keeps serving a cached response when the server sends Last-Modified without Cache-Control".

## 必要なもの / Requirements

- Xcode 27.3 (Swift 6.4.4) 以降 / Xcode 27.3 (Swift 6.4.4) or later
- macOS 15 以降 / macOS 15 or later
- Python 3

## 流し方 / Run

```sh
./run.sh <サーバーのモード / server mode> <クライアントのモード / client mode> [回数 / attempts] [Last-Modified を何秒前にするか / Last-Modified age in seconds]
```

```sh
./run.sh plain shared          # Last-Modified だけ + URLSession.shared / Last-Modified only + URLSession.shared
./run.sh plain uncached        # キャッシュを持たないセッション / a session with no cache
./run.sh plain policy          # リクエストごとに reloadIgnoringLocalCacheData / reloadIgnoringLocalCacheData per request
./run.sh nostore shared        # Cache-Control: no-store を付けたサーバー / the server adds Cache-Control: no-store
./run.sh bare shared           # Last-Modified も無いサーバー / the server sends no Last-Modified either
./run.sh plain shared 14 40    # Last-Modified を 40 秒前にして 14 回 / Last-Modified 40 seconds ago, 14 attempts
./run.sh plain shared 14 100   # Last-Modified を 100 秒前にして 14 回 / Last-Modified 100 seconds ago, 14 attempts
```

サーバーは `127.0.0.1` の空いていそうなポートで起動し、クライアントが終わると止まります。
The server starts on a port on `127.0.0.1` that is likely to be free and stops when the client finishes.

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `server.py` | GET のたびに、それまでに受けたリクエストの数を本文で返す / Answers every GET with the number of requests it has received so far |
| `client.swift` | 同じ URL を 1 秒おきに取りに行き、受け取った本文を出す / Fetches the same URL once a second and prints the body it got |
| `run.sh` | サーバーを起動してクライアントを流し、サーバーに届いたリクエストの数を出す / Starts the server, runs the client, and prints how many requests reached the server |
