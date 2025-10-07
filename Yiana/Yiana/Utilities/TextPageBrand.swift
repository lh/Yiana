#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum TextPageBrand {
    #if os(iOS)
    static let accentColor: UIColor = UIColor(named: "AccentColor") ?? UIColor.systemBlue
    #else
    static let accentColor: NSColor = NSColor(named: "AccentColor") ?? NSColor.systemBlue
    #endif
}
