import AppKit
import SwiftUI
import XCTest
@testable import LiteTextEditor

final class UndoCorrectnessTests: XCTestCase {
    func testBoldUndoRestoresOriginalAttributesInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("Hello world")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        controller.toggleBold()
        XCTAssertTrue(font(at: 0, in: textView).fontDescriptor.symbolicTraits.contains(.bold))

        textView.undoManager?.undo()
        XCTAssertFalse(font(at: 0, in: textView).fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertEqual(textView.string, "Hello world")

        textView.undoManager?.redo()
        XCTAssertTrue(font(at: 0, in: textView).fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testHighlightUndoRestoresOriginalAttributesInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("Hello world")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        controller.toggleHighlight()
        XCTAssertNotNil(textView.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil))

        textView.undoManager?.undo()
        XCTAssertNil(textView.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil))

        textView.undoManager?.redo()
        XCTAssertNotNil(textView.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil))
    }

    func testAlignmentUndoRestoresOriginalParagraphStyleInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("First paragraph\nSecond paragraph")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        controller.setAlignment(.center)
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).alignment, .center)

        textView.undoManager?.undo()
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).alignment, .left)
        XCTAssertEqual(textView.string, "First paragraph\nSecond paragraph")

        textView.undoManager?.redo()
        XCTAssertEqual(paragraphStyle(at: 0, in: textView).alignment, .center)
    }

    func testBulletedListUndoRestoresOriginalTextInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("First\nSecond")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))

        controller.togglePlainList()
        XCTAssertEqual(textView.string, "- First\n- Second")

        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "First\nSecond")

        textView.undoManager?.redo()
        XCTAssertEqual(textView.string, "- First\n- Second")
    }

    func testNumberedListUndoRestoresOriginalTextInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("First\nSecond")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))

        controller.toggleNumberedList()
        XCTAssertEqual(textView.string, "1. First\n2. Second")

        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "First\nSecond")

        textView.undoManager?.redo()
        XCTAssertEqual(textView.string, "1. First\n2. Second")
    }

    func testIndentUndoRestoresOriginalTextInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("First\nSecond")
        let textView = fixture.textView
        controller.textView = textView
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))

        controller.increaseIndent()
        XCTAssertEqual(textView.string, "\tFirst\n\tSecond")

        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "First\nSecond")

        textView.undoManager?.redo()
        XCTAssertEqual(textView.string, "\tFirst\n\tSecond")
    }

    func testSpellingCorrectionUndoRestoresOriginalWordInOneStep() {
        let controller = EditorController()
        let fixture = makeTextViewFixture("teh word")
        let textView = fixture.textView
        controller.textView = textView
        controller.spellCorrectionState = SpellCorrectionState(
            isPresented: true,
            issueRange: NSRange(location: 0, length: 3),
            originalWord: "teh",
            suggestions: ["the"],
            selectedSuggestionIndex: 0,
            statusText: "Possible spelling issue"
        )

        controller.applyCurrentSpellingCorrection()
        XCTAssertEqual(textView.string, "the word")

        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "teh word")

        textView.undoManager?.redo()
        XCTAssertEqual(textView.string, "the word")
    }

    private struct TextViewFixture {
        let window: NSWindow
        let textView: AutocompleteTextView
    }

    private func makeTextViewFixture(_ string: String) -> TextViewFixture {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: AutocompleteTextView.pageTextWidth,
                height: AutocompleteTextView.textLayoutDimensionLimit
            )
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = AutocompleteTextView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: AutocompleteTextView.paperWidth + (AutocompleteTextView.deskPadding * 2),
                height: AutocompleteTextView.pageHeight + (AutocompleteTextView.deskPadding * 2)
            ),
            textContainer: textContainer
        )
        textView.allowsUndo = true
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black,
            .paragraphStyle: leftParagraphStyle()
        ]
        textView.textStorage?.setAttributedString(
            NSAttributedString(
                string: string,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: leftParagraphStyle()
                ]
            )
        )
        let scrollView = NSScrollView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 700,
                height: 900
            )
        )
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 900),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = scrollView
        window.makeFirstResponder(textView)
        textView.undoManager?.removeAllActions()
        return TextViewFixture(window: window, textView: textView)
    }

    private func font(at location: Int, in textView: AutocompleteTextView) -> NSFont {
        textView.textStorage?.attribute(.font, at: location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 11)
    }

    private func paragraphStyle(at location: Int, in textView: AutocompleteTextView) -> NSParagraphStyle {
        textView.textStorage?.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            ?? NSParagraphStyle.default
    }

    private func leftParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        return paragraphStyle
    }
}
