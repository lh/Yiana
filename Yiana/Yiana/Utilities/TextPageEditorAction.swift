//
//  TextPageEditorAction.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Simple enum describing formatting commands that the text page editor can
//  perform. The UIKit/AppKit bridge picks these up and mutates the underlying
//  text view accordingly.
//

import Foundation

enum TextPageEditorAction: Equatable {
    case bold
    case italic
    case unorderedList
    case orderedList
    case blockquote
    case horizontalRule
    case heading(level: Int)
}
