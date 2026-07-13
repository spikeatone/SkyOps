//
//  Typography.swift
//  SkyOps — Karla (bundled OFL) font helper
//
//  The Figma designs use Karla (Light/Regular/Medium/SemiBold/Bold). The static
//  weights are bundled in Resources/Fonts and registered via Info.plist
//  UIAppFonts. `Font.karla(_:_:)` maps a SwiftUI weight to the matching Karla
//  face; Font.custom falls back to the system font if a face is missing, so
//  this degrades gracefully.
//

import SwiftUI

extension Font {
    static func karla(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(Font.karlaFaceName(weight), size: size)
    }

    private static func karlaFaceName(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: return "Karla-Light"
        case .medium:                    return "Karla-Medium"
        case .semibold:                  return "Karla-SemiBold"
        case .bold, .heavy, .black:      return "Karla-Bold"
        default:                         return "Karla-Regular"
        }
    }
}
