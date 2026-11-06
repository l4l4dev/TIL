import Testing

struct NoAppTests {
    @Test func a() async throws { log("noapp.a start"); try await Task.sleep(for: .seconds(3)); log("noapp.a end") }
    @Test func b() async throws { log("noapp.b start"); try await Task.sleep(for: .seconds(3)); log("noapp.b end") }
    @Test func c() async throws { log("noapp.c start"); try await Task.sleep(for: .seconds(3)); log("noapp.c end") }
}
