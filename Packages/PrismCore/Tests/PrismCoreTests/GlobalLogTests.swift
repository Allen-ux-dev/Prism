import Foundation
import Testing
@testable import PrismUIBridge

@Test func globalLogIsBoundedAndExportsNewestEntries() async {
    let store = PrismLogStore(capacity: 3)
    for index in 0..<5 {
        await store.append(level: .info, category: .ui, message: "event-\(index)")
    }
    let entries = await store.entries()
    #expect(entries.map(\.message) == ["event-2", "event-3", "event-4"])
    let text = await store.exportText()
    #expect(!text.contains("event-0"))
    #expect(text.contains("event-4"))
}

@Test func globalLogFiltersAndRedactsSensitiveMetadata() async {
    let store = PrismLogStore(capacity: 10)
    await store.append(level: .warning, category: .source, message: "refresh", metadata: [
        "url": "https://repo.example/",
        "token": "secret-token",
        "Password": "secret-password"
    ])
    await store.append(level: .error, category: .transaction, message: "failed")

    let sourceEntries = await store.entries(category: .source)
    #expect(sourceEntries.count == 1)
    #expect(sourceEntries[0].metadata["token"] == "<redacted>")
    #expect(sourceEntries[0].metadata["Password"] == "<redacted>")
    #expect(sourceEntries[0].metadata["url"] == "https://repo.example/")
    #expect((await store.entries(minimumLevel: .error)).map(\.message) == ["failed"])
}
