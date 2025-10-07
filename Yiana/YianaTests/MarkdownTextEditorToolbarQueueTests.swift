//
//  MarkdownTextEditorToolbarQueueTests.swift
//  YianaTests
//
//  Created by GPT-5 Codex on 10/07/2025.
//

import XCTest
@testable import Yiana

#if os(iOS)
import SwiftUI
import UIKit

final class MarkdownTextEditorToolbarQueueTests: XCTestCase {

    func testRapidHorizontalRuleActionsProcessWithoutCrash() {
        let expectation = expectation(description: "Toolbar queue drains")

        var text = ""
        var cursorPosition: Int? = 0
        var pendingAction: TextPageEditorAction? = nil

        let editor = MarkdownTextEditor(
            text: Binding(
                get: { text },
                set: { text = $0 }
            ),
            cursorPosition: Binding(
                get: { cursorPosition },
                set: { cursorPosition = $0 }
            ),
            pendingAction: Binding(
                get: { pendingAction },
                set: { pendingAction = $0 }
            ),
            onEditingBegan: nil,
            onEditingEnded: nil
        )

        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = text
        textView.selectedRange = NSRange(location: 0, length: 0)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        window.rootViewController?.view.addSubview(textView)

        DispatchQueue.main.async {
            for _ in 0..<5 {
                coordinator.handle(action: .horizontalRule, on: textView)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(text.components(separatedBy: "---").count - 1, 5, "Expected five horizontal rules to be inserted")
            XCTAssertNotNil(cursorPosition)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.5)
    }
}
#endif
