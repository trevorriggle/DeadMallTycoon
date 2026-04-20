import Foundation

// v8: G.warnings entry
struct Warning: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let text: String
    let severity: Severity
    var age: Int
}

// v8: G.thoughtsLog entry
struct ThoughtLogEntry: Identifiable, Equatable {
    let id: UUID
    let visitorName: String
    let personality: String
    let text: String
    let timestamp: Date

    init(visitorName: String, personality: String, text: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.visitorName = visitorName
        self.personality = personality
        self.text = text
        self.timestamp = timestamp
    }
}
