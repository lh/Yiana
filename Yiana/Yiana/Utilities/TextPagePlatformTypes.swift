#if os(iOS)
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
#endif
