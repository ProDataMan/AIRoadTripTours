import Foundation

/// Represents a user's area of interest for tour content personalization.
public protocol Interest: Hashable, Codable, Sendable {
    /// Unique identifier for the interest.
    var id: UUID { get }

    /// Display name of the interest.
    var name: String { get }

    /// Category grouping for related interests.
    var category: InterestCategory { get }
}

/// Categories for organizing user interests.
public enum InterestCategory: String, Codable, Sendable, CaseIterable {
    case nature
    case food
    case history
    case entertainment
    case adventure
    case culture
    case shopping
    case relaxation
    case scenic
    case wildlife
}

/// Concrete implementation of an interest.
public struct UserInterest: Interest {
    public let id: UUID
    public let name: String
    public let category: InterestCategory

    public init(id: UUID = UUID(), name: String, category: InterestCategory) {
        self.id = id
        self.name = name
        self.category = category
    }
}
