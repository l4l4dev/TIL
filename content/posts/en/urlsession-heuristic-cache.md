---
title: 'URLSession.shared keeps serving a cached response when the server sends Last-Modified without Cache-Control'
description: 'When a server sends Last-Modified but no Cache-Control, URLSession.shared answered the second and later requests from its cache without contacting the server. It kept doing so for a little under 10% of the time since Last-Modified. I stopped it with a cacheless session in the app and no-store on the server.'
lang: en
translationKey: urlsession-heuristic-cache
publishDate: 2026-11-20
tags: ['Swift', 'URLSession', 'iOS', 'macOS']
draft: false
---

[FirnPlanner](https://firnplanner.l4l4.dev/) is a day planner for macOS that I build on my own, and I am developing a feature that syncs its data between devices. During that work I added a new header to the server response, and the app stopped with an error because it could not read that header. The app talked to the server through `URLSession.shared`, and it was returning a response it had received earlier from its cache. The server response had `Last-Modified` and no `Cache-Control`.

I checked whether the same thing happens in a small example.

## With only Last-Modified, the second request never reached the server

The server answers every GET with the number of requests it has received so far. The only caching-related header is `Last-Modified`, set to 30 days ago. There is no `Cache-Control` and no `Expires`.

```python
body = f"answer #{count}".encode()
self.send_response(200)
self.send_header("Content-Type", "text/plain")
self.send_header("Content-Length", str(len(body)))
self.send_header("Last-Modified", LAST_MODIFIED)
self.end_headers()
self.wfile.write(body)
```

The client fetches the same URL three times, one second apart.

```swift
for attempt in 1...attempts {
    let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
    print("attempt \(attempt) got \"\(String(decoding: data, as: UTF8.self))\"")
    try await Task.sleep(for: .seconds(1))
}
```

Here is what happened as I changed the server headers and the client setup.

| Server response | Client | Bodies received | Requests that reached the server |
|---|---|---|---|
| `Last-Modified` only | `URLSession.shared` | #1, #1, #1 | **1** |
| `Last-Modified` only | a session with no cache | #1, #2, #3 | 3 |
| `Last-Modified` only | `URLSession.shared`, request set to `reloadIgnoringLocalCacheData` | #1, #2, #3 | 3 |
| `Last-Modified` and `Cache-Control: no-store` | `URLSession.shared` | #1, #2, #3 | 3 |
| neither | `URLSession.shared` | #1, #2, #3 | 3 |

In the first row, the second and third requests did not reach the server. No conditional request with `If-Modified-Since` arrived either. Without `Last-Modified`, every request arrived, so whether the cache answers depends on `Last-Modified` being there.

## The cache answered for a little under 10% of the time since Last-Modified

I moved `Last-Modified` closer to now and fetched 14 times, one second apart.

| `Last-Modified` | When requests reached the server (seconds from start) |
|---|---|
| 40 seconds ago | 0.0, 3.1, 6.2, 9.3, 13.5 |
| 100 seconds ago | 0.0, 9.2 |

The cache answered for about 3 seconds with 40 seconds ago, and for about 9 seconds with 100 seconds ago. I only looked once a second, so each switch can be off by up to a second.

The HTTP caching specification ([RFC 9111, section 4.2.2](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2.2)) lets a cache estimate an expiration time from `Last-Modified` and similar headers when the response does not state one. The example it gives is 10% of the time since `Last-Modified`. What I measured is a little shorter than that, but close.

At the same ratio, a `Last-Modified` of 30 days ago would be answered from the cache for close to 3 days. That is arithmetic. I did not measure across 3 days. The experiment also stays within one launch, so I did not measure whether this carries over to the next launch.

## I stopped it in both the app and the server

In the app, I create a session that has no cache and use that.

```swift
let configuration = URLSessionConfiguration.default
configuration.urlCache = nil
configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
let session = URLSession(configuration: configuration)
```

The session can be passed in from outside, so each request also sets `cachePolicy = .reloadIgnoringLocalCacheData`. As the third row shows, requests reach the server even when `URLSession.shared` is passed in.

On the server, every response now carries `Cache-Control: no-store`, including errors. Fixing the app does not change what builds from before the fix do, or what a proxy in between does. As the fourth row shows, with `no-store` every request arrives even with `URLSession.shared`.

## Summary

- `URLSession.shared` can answer from its cache when a response has `Last-Modified` and no `Cache-Control`. During that time, requests do not reach the server
- For an API where the client must read the current state every time, have the server return `Cache-Control: no-store`
- The client can also stop it, with a session whose `urlCache` is `nil` or with `reloadIgnoringLocalCacheData` on the request

The scripts are in [samples/urlsession-heuristic-cache](https://github.com/l4l4dev/TIL/tree/main/samples/urlsession-heuristic-cache). `./run.sh plain shared` is the first row of the table, and `./run.sh plain shared 14 40` is the 40-seconds-ago experiment.

Tested with Xcode 27.3 beta 2 (27C5035i), Swift 6.4.4, macOS 27.3.
