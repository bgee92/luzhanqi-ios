import CoreText
import LuzhanqiKit
import SwiftUI

/// The app's fixed palette. The board, pieces and paper screens are physical
/// objects, so the app keeps this one look in light and dark mode.
enum Palette {
    static let ground = Color(hex: 0xD9CFA0)
    static let paperHi = Color(hex: 0xF6ECD2)
    static let ink = Color(hex: 0x4A3423)
    static let inkSoft = Color(hex: 0x5A4330)
    static let rail = Color(hex: 0x3B2A1D)
    static let contour = Color(hex: 0x6B5A3A)
    static let riverEdge = Color(hex: 0x9DB8B1)
    static let riverMid = Color(hex: 0x86A6A2)
    static let bank = Color(hex: 0x5F7360)
    static let mountainBack = Color(hex: 0x7D8F86)
    static let mountainFront = Color(hex: 0x506259)
    static let bridge = Color(hex: 0x8A6A45)
    static let camp = Color(hex: 0xCFE0C2)
    static let stake = Color(hex: 0x6B4A2B)
    static let headquarters = Color(hex: 0xE8C896)
    static let sandbag = Color(hex: 0xC4AE7C)
    static let sandbagEdge = Color(hex: 0x6B5434)

    static let gold = Color(hex: 0xE9B949)
    static let jade = Color(hex: 0x3F8F68)
    static let vermilion = Color(hex: 0xD2412B)
    static let cream = Color(hex: 0xFBEFCF)
    static let night = Color(hex: 0x121A2E)
    static let red = Color(hex: 0xB3311F)
    static let redDeep = Color(hex: 0x7A170F)
    static let blue = Color(hex: 0x22408A)
    static let blueDeep = Color(hex: 0x12285C)

    /// Lacquer gradient stops for each side's pieces, top to bottom.
    static func lacquer(_ side: Side) -> [Color] {
        side == .red
            ? [Color(hex: 0xDC4B35), Color(hex: 0xA8291B), Color(hex: 0x76160E)]
            : [Color(hex: 0x4167BB), Color(hex: 0x21408B), Color(hex: 0x132A5F)]
    }

    static let goldMetal = [Color(hex: 0xFFF0B3), Color(hex: 0xE8B443), Color(hex: 0xA26C14)]
    static let silverMetal = [Color.white, Color(hex: 0xD3D8DF), Color(hex: 0x8D95A2)]
}

/// The three bundled typefaces (see Tools/subset_fonts.py). They are subset to
/// the characters the app uses; anything else falls back to the system font.
enum AppFont {
    static let serifName = "NotoSerifSC-Black"
    static let brushName = "MaShanZheng-Regular"
    static let displayName = "BigShouldersDisplay-ExtraBold"

    /// Registers the bundled fonts for this process; call once at launch.
    static func registerBundledFonts() {
        for file in ["NotoSerifSC-Black-Subset", "MaShanZheng-Subset", "BigShouldersDisplay-ExtraBold-Subset"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Heavy Song-style serif for Chinese names and headings.
    static func serif(_ size: CGFloat) -> Font { .custom(serifName, fixedSize: size) }
    /// Brush script for the title and result seals.
    static func brush(_ size: CGFloat) -> Font { .custom(brushName, fixedSize: size) }
    /// Condensed display face for English labels and headings.
    static func display(_ size: CGFloat) -> Font { .custom(displayName, fixedSize: size) }

    /// A heading face for the current language.
    static func heading(_ size: CGFloat, _ language: AppLanguage) -> Font {
        language == .chinese ? serif(size) : display(size * 1.2)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
