import SwiftUI

enum LogCategory: String, CaseIterable, Identifiable {
    case meal = "meal"
    case bath = "bath"
    case bedtime = "bedtime"
    case pickup = "pickup"
    case doctor = "doctor"
    case activity = "activity"
    case purchase = "purchase"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meal: return "Made Meal"
        case .bath: return "Bath Time"
        case .bedtime: return "Bedtime"
        case .pickup: return "Pickup/Dropoff"
        case .doctor: return "Doctor Visit"
        case .activity: return "Activity/Play"
        case .purchase: return "Purchase"
        }
    }

    var emoji: String {
        switch self {
        case .meal: return "🍳"
        case .bath: return "🛁"
        case .bedtime: return "📚"
        case .pickup: return "🚗"
        case .doctor: return "🏥"
        case .activity: return "🎨"
        case .purchase: return "💰"
        }
    }

    var color: Color {
        switch self {
        case .meal: return .orange
        case .bath: return .cyan
        case .bedtime: return .indigo
        case .pickup: return .green
        case .doctor: return .red
        case .activity: return .purple
        case .purchase: return .yellow
        }
    }

    var subcategories: [String]? {
        switch self {
        case .meal: return ["Breakfast", "Lunch", "Dinner", "Snack"]
        default: return nil
        }
    }
}
