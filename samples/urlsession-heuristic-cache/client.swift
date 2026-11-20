import Foundation

// usage: swift client.swift <port> shared|uncached|policy [attempts]
//   shared    URLSession.shared, default cache policy
//   uncached  a session with no URLCache that always reloads
//   policy    URLSession.shared, but each request says reloadIgnoringLocalCacheData
let port = CommandLine.arguments[1]
let mode = CommandLine.arguments[2]
let attempts = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 3
// A new URL on every run, so an answer stored by an earlier run is never reused.
let url = URL(string: "http://127.0.0.1:\(port)/file?run=\(UUID().uuidString)")!

let session: URLSession
if mode == "uncached" {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration)
} else {
    session = .shared
}

let start = Date()
for attempt in 1...attempts {
    var request = URLRequest(url: url)
    if mode == "policy" { request.cachePolicy = .reloadIgnoringLocalCacheData }
    let (data, _) = try await session.data(for: request)
    let elapsed = String(format: "%4.1f", Date().timeIntervalSince(start))
    print("client: \(elapsed)s attempt \(attempt) got \"\(String(decoding: data, as: UTF8.self))\"")
    try await Task.sleep(for: .seconds(1))
}
