import Testing

@MainActor
struct LaunchingUITests {
    @Test func a() async throws { try await launchAndWait("launch.a") }
    @Test func b() async throws { try await launchAndWait("launch.b") }
    @Test func c() async throws { try await launchAndWait("launch.c") }
}

@MainActor
@Suite(.serialized)
struct SerializedUITests {
    @Test func a() async throws { try await launchAndWait("serial.a") }
    @Test func b() async throws { try await launchAndWait("serial.b") }
    @Test func c() async throws { try await launchAndWait("serial.c") }
}
