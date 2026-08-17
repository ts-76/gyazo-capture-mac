import Foundation

struct CollectionPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var collectionID: String

    init(id: UUID = UUID(), name: String, collectionID: String) {
        self.id = id
        self.name = name
        self.collectionID = collectionID
    }

    static func extractCollectionID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host == "gyazo.com" || host.hasSuffix(".gyazo.com") {
            let components = url.pathComponents.filter { $0 != "/" }
            guard components.count == 2,
                  components[0] == "collections",
                  isValidCollectionID(components[1]) else {
                return nil
            }
            return components[1]
        }

        return isValidCollectionID(trimmed) ? trimmed : nil
    }

    private static func isValidCollectionID(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}
