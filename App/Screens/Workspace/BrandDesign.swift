import AppKit
import SwiftUI

enum BrandTheme {
    static let accent = Color(hex: "#7755D8")
    static func background(_ dark: Bool) -> Color { Color(hex: dark ? "#151420" : "#F8F6FD") }
    static func sidebar(_ dark: Bool) -> Color { Color(hex: dark ? "#201D31" : "#EEE9FA") }
    static func surface(_ dark: Bool) -> Color { Color(hex: dark ? "#252135" : "#FFFFFF") }
}

enum BrandAssets {
    static let image: NSImage = {
        if let url = Bundle.main.url(forResource: "BrandLogo", withExtension: "png"), let image = NSImage(contentsOf: url) { return image }
        if let root = ProcessInfo.processInfo.environment["IGET_RESOURCE_ROOT"], let image = NSImage(contentsOfFile: root + "/Config/BrandLogo.png") { return image }
        return NSImage(size: NSSize(width: 32, height: 32))
    }()
}

struct BrandMark: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var size: CGFloat = 36
    var body: some View { Image(nsImage: BrandAssets.image).resizable().interpolation(.high).aspectRatio(contentMode: .fit).frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.23)).accessibilityLabel("iGet") }
}
