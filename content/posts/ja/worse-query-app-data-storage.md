---
title: 'iOS のサンドボックス脱出 PoC「worse_query」で、自分のアプリのデータの置き方を見直す'
description: '2026-11-08 に公開された worse_query は、App Group のコンテナを用意したアプリから、ほかのアプリのコンテナにあるファイルにアクセスできる PoC です。WebView 固有の問題ではありません。悪意のあるアプリを入れて動かすことが前提で、脱獄とも関係しません。アプリの開発者が見直す所として、平文で置いた秘密、WebView のデータ、課金の状態の持ち方を整理しました。'
lang: ja
translationKey: worse-query-app-data-storage
publishDate: 2026-11-11
tags: ['iOS', 'Security']
draft: false
---

2026-11-08 に、iOS のサンドボックス脱出の PoC「worse_query」が GitHub で公開されました。端末に入れたアプリから、ほかのアプリのコンテナにあるファイルにアクセスできるというものです。暗号資産の取引所やセキュリティ企業が警告を出したので、ウォレットの話として広まりましたが、影響はウォレットに限りません。アプリのコンテナに平文で置いたものは、ほかのアプリから読まれ得る。そう考えて、自分のアプリがデータをどう置いているかを見直すきっかけにするのがよさそうです。

この記事は、公開された情報を 2026-11-11 時点で読んでまとめたものです。PoC を手元で動かしてはいません。

## worse_query は、App Group のコンテナを用意したアプリから、ほかのアプリのファイルにアクセスできる

[worse_query の README](https://github.com/forcequitOS/worse_query) によると、対象は iOS 26.0〜26.7.2 と iOS 27.2 です。README は、これを開発者向けの PoC で、それ単体では役に立たないものだと説明しています。使うには、PoC を組み込むアプリに App Group のコンテナを用意する必要があります。8 月に同じ作者が公開した [bad_query](https://github.com/forcequitOS/bad_query) の後継です。

README には、アクセスできるパスの一覧が載っています。

```
/var/containers/Data/System (iOS 27)
/var/containers/Shared/SystemGroup/* (iOS 27)
/var/mobile/Containers/Data/Application/*
/var/mobile/Containers/Data/InternalDaemon/*
/var/mobile/Containers/Data/PluginKitPlugin/*
/var/mobile/Containers/Shared/AppGroup/*
/var/mobile/Containers/Shared/AppGroup (iOS 27)
```

アプリの開発者に関係が深いのは、`Data/Application/*` と `Shared/AppGroup/*` です。前者は各アプリのデータのコンテナ (Documents、Library、tmp が入る場所) で、後者はアプリとウィジェットや拡張機能が共有する App Group のコンテナです。`PluginKitPlugin/*` は、拡張機能のコンテナにあたります。

仕組みについて、README はこれ以上説明していません。ソースのコメントを見ると、App Group のコンテナの場所を、コンテナを管理するシステムのデーモン containermanagerd に問い合わせる処理を使っています。WebView や特定のフレームワークの不具合ではないので、WebView を使っていないアプリでも、コンテナに置いたファイルは同じように扱われます。なお、リポジトリには pathleak という補助コードも入っています。他のアプリのコンテナのパス（UUID）を inode 番号の総当たりで割り出すもので、攻撃側が狙う先のパスを知る手段にあたります。

## 前提は、悪意のあるアプリを入れて動かすこと

worse_query は、それだけで端末を乗っ取るものではありません。PoC を組み込んだアプリを端末に入れて、動かす必要があります。README は「これは脱獄とは関係がなく、これからも関係しない」と明記しています。

セキュリティ企業 SlowMist の[アラート](https://x.com/SlowMist_Team/status/2120045378792010166)も、同じ読み方です。コンテナのサンドボックス脱出で、脱獄ではない。悪用に成功したアプリは、システムのパスにアクセスし、ほかのアプリのデータを読み書きできる。不具合そのものは資産を盗まず、出どころの分からないアプリ (サイドロードした IPA など) を入れたときに危険が始まる、という説明です。取引所の Binance の[警告](https://x.com/binance/status/2120093246399430770)は、「悪意のあるアプリがほかのアプリのローカルのファイルを読める」「Binance に限らない iOS の問題だ」と書いています。

作者は X で、この点をはっきり書いています。「App Store のアプリからでも悪用できる。攻撃者は App Review を通過すればいいだけだ」という投稿です（[投稿](https://x.com/forcequitOS/status/2120249200478961791)、2026-11-11）。App Group は App Store のアプリでも普通に使える機能なので、前提の部分は満たせます。作者はこの投稿で、審査を通過してしまった悪性アプリの例として、SlowMist が分析した FomoPeek にも触れています。実際に worse_query を悪用したアプリが App Store で配られた例があるかは、確認できていません。

## 2026-11-11 の時点で、Apple は修正を公表していない

Apple は 2026-11-09 に iOS 27.2.1 と iOS 26.7.3 を出しました。どちらのセキュリティノート ([27.2.1](https://support.apple.com/en-us/149715)、[26.7.3](https://support.apple.com/en-us/149716)) にも、worse_query やサンドボックスに当たる項目はなく、containermanagerd という語も出てきません。直したのは Bluetooth、AirPlay、メッセージなどの不具合です。

作者は X で、worse_query は iOS 27.2.1 と 27.3 beta 1 ではまだ直っていないと明言しています。直ったら README の対応バージョンを更新する、とも書いています（[投稿](https://x.com/forcequitOS/status/2120125653085270418)、2026-11-10）。

SlowMist のアラートは「iOS を最新に保ち、Apple の修正が出たらすぐ入れる」と勧めています。これは修正が出たら入れるという助言で、27.2.1 で直ったとは書いていません。27.2.1 に上げれば防げる、という読み方はしないほうが安全です。

対象のバージョンの書き方も、出典によって違います。README は 26.0〜26.7.2 と 27.2、Binance は 26.7.1、27.0.1、27.2 と書いています。

前作の bad_query は、README で iOS 26.0〜26.6.1 と iOS 27.0 beta 4 を対象としており、iOS 26.7 は対象に含まれていません。

## 開発者が見直すのは、コンテナに平文で置いているもの

修正がいつ出るかに関係なく、アプリの開発者が手を付けられるのは、自分のアプリが端末に何をどう置いているかです。サンドボックスは、ほかのアプリからコンテナを守る仕組みです。その前提が崩れたときに困るものを洗い出します。

### 秘密は、ファイルではなくキーチェーンに入れる

ログインのトークン、API キー、ウォレットの秘密鍵やリカバリーフレーズを、ファイルや `UserDefaults` に平文で置いていないかを確かめます。`UserDefaults` の中身は、コンテナの `Library/Preferences` に plist として保存されます。SQLite、Core Data、SwiftData のストアや、`Documents` と `Caches` に書いたファイルも、コンテナの中です。

秘密はキーチェーンに入れます。公開された PoC が届くのはコンテナの中のファイルまでで、キーチェーンの項目はコンテナの中のファイルではなく、システムのセキュリティデーモンが管理する仕組みです。少なくとも今回公開された手法の到達範囲には、キーチェーンは含まれていません。将来の亜種まで保証する話ではないので、キーチェーンに入れたうえで、端末に置く秘密の量そのものを減らすのが確実です。

ファイルに置くしかない大きなデータは、CryptoKit などで暗号化し、鍵だけをキーチェーンに置く方法があります。

ファイルの保護クラス (Data Protection) は、端末がロックされている間にファイルを暗号化する仕組みです。筆者の理解では、端末が使われている間に動いている別のアプリによる読み出しは防げません。保護クラスを付けただけで今回のような読み出しを防げる、とは考えないほうがよいでしょう。

### WebView のデータも、アプリのコンテナに残る

SlowMist と、同社の CISO 23pds の[投稿](https://x.com/im23pds/status/2119985290907656563)は、WebView のキャッシュを平文で置くウォレットも危ないと挙げています。WebView の不具合だからではなく、WebView が保存するデータもアプリのコンテナに入るからです。

`WKWebView` は、既定のデータストア (`WKWebsiteDataStore.default()`) を使うと、Cookie、localStorage、IndexedDB、キャッシュをコンテナの中に保存します。ログインのセッションの Cookie や、Web 側が localStorage に置いたトークンも、そのままファイルとして残ります。

残す必要のない画面では、保存しないデータストアを使えます。

```swift
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()
let webView = WKWebView(frame: .zero, configuration: config)
```

残す必要がある画面では、ログアウトのときに `removeData(ofTypes:modifiedSince:)` で消す、Web 側で長く有効なトークンを localStorage に置かない、といった対策を Web とアプリの両方で考えます。

### 課金の状態は、端末のフラグで決めない

`UserDefaults` に `isPro = true` のようなフラグを置いて、それだけで有料の機能を有効にしているなら、見直す時期です。SlowMist の説明どおりにほかのアプリのデータを書き換えられるなら、このフラグも外から書き換えられます。worse_query が出る前から、脱獄した端末では同じことができました。

StoreKit 2 なら、起動のたびに `Transaction.currentEntitlements` を見て、App Store が署名した取引の記録から有料の機能を有効にするかを決められます。フラグは表示を速くするための控えとして使い、正しい状態は取引の記録から取り直します。

```swift
for await result in Transaction.currentEntitlements {
    if case .verified(let transaction) = result,
       transaction.productID == "pro_monthly" {
        // 有料の機能を有効にする
    }
}
```

サーバーで機能を出し分けているなら、サーバー側で確かめた課金の状態で決めます。

### App Group のコンテナに置いたものも同じ

ウィジェットや拡張機能とデータを共有するための App Group のコンテナも、README の一覧に入っています。アプリ本体のコンテナと同じ基準で、何を置いているかを確かめます。

## 利用者に伝えられること

アプリの側でできるのは置き方の見直しですが、サポートなどで利用者に聞かれたときは、SlowMist と Binance の助言がそのまま使えます。出どころの分からないアプリを入れない、入れたものは消す、iOS を最新にして、修正が出たら入れる、の 3 つです。SlowMist は、ウォレットのある端末に信頼できないアプリを入れていたなら、きれいな端末で作った新しいウォレットへ資産を移すことも勧めています。

## 確認できていないこと

- App Store で配られたアプリが worse_query を悪用した例があるか
- Apple が worse_query を直したか、直す予定があるか

## まとめ

- worse_query は、App Group のコンテナを用意したアプリから、ほかのアプリのコンテナのファイルにアクセスできる PoC。前提は悪意のあるアプリを入れて動かすことで、脱獄ではない
- 2026-11-11 の時点で、Apple のセキュリティノートに修正の記載はない
- アプリの開発者は、コンテナに平文で置いた秘密、WebView のデータ、端末のフラグだけで決めている課金の状態を見直す

## 出典

- [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) (README とソース、2026-11-08 公開)
- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) (前作)
- [作者による公開の投稿](https://x.com/forcequitOS/status/2119475139528020218) (X、2026-11-08)
- [SlowMist のアラート](https://x.com/SlowMist_Team/status/2120045378792010166) (X、2026-11-10)
- [23pds (SlowMist) の投稿](https://x.com/im23pds/status/2119985290907656563) (X、2026-11-10)
- [Binance の警告](https://x.com/binance/status/2120093246399430770) (X、2026-11-10)
- [Apple: About the security content of iOS 27.2.1 and iPadOS 27.2.1](https://support.apple.com/en-us/149715)
- [Apple: About the security content of iOS 26.7.3 and iPadOS 26.7.3](https://support.apple.com/en-us/149716)
- [作者による修正状況の投稿](https://x.com/forcequitOS/status/2120125653085270418) (X、2026-11-10)
- [作者による App Store のアプリについての投稿](https://x.com/forcequitOS/status/2120249200478961791) (X、2026-11-11)
