import SwiftUI

enum AppColors {
    /// Brand green; also the asset-catalog accent color.
    static let seed = Color(red: 0.106, green: 0.498, blue: 0.361)

    static let income = adaptive(light: (0.18, 0.49, 0.20), dark: (0.40, 0.73, 0.42))
    static let expense = adaptive(light: (0.78, 0.16, 0.16), dark: (0.94, 0.33, 0.31))
    static let transfer = Color.secondary
    /// Differences and soft warnings (yellow/amber).
    static let warning = adaptive(light: (0.80, 0.52, 0.00), dark: (0.98, 0.75, 0.25))

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double))
        -> Color
    {
        Color(
            uiColor: UIColor { traits in
                let c = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
            })
    }
}
