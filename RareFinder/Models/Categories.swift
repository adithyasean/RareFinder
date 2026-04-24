import Foundation

enum BountyCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case retroTech = "Retro Tech"
    case fineArt = "Fine Art"
    case fuelGrid = "Fuel Grid"
    case luxury = "Luxury"
    case services = "Services"
    case limitedGear = "Limited Gear"
    case medical = "Medical"
    case books = "Rare Books"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .retroTech: return "iphone.gen1"
        case .fineArt: return "building.columns.fill"
        case .fuelGrid: return "fuelpump.fill"
        case .luxury: return "trophy.fill"
        case .services: return "cup.and.saucer.fill"
        case .limitedGear: return "shippingbox.fill"
        case .medical: return "cross.case.fill"
        case .books: return "book.closed.fill"
        }
    }
}
