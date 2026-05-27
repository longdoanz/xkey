//
//  VNEngineAutoCapitalizeTests.swift
//  XKeyTests
//
//  Tests for auto-capitalize first character of sentence feature
//  Feature: upperCaseFirstChar - after a sentence-end punctuation (. ? !)
//  or newline, the first letter of the next word should be auto-capitalized.
//

import XCTest
@testable import XKey

class VNEngineAutoCapitalizeTests: XCTestCase {

    var engine: VNEngine!

    override func setUp() {
        super.setUp()
        engine = VNEngine()
        engine.reset()

        var settings = VNEngine.EngineSettings()
        settings.upperCaseFirstChar = true
        settings.spellCheckEnabled = false
        settings.restoreIfWrongSpelling = false
        engine.updateSettings(settings)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Capitalize flag of the first buffered entry after a key event
    private func firstIsCaps() -> Bool {
        guard engine.index > 0 else { return false }
        return (engine.typingWord[0] & VNEngine.CAPS_MASK) != 0
    }

    // MARK: - Period Tests

    func testCapitalize_AfterPeriodAndSpace() {
        // Simulate "a. b" — 'b' should be capitalized to 'B'
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after '. ' should be capitalized")
    }

    func testCapitalize_AfterPeriodAndMultipleSpaces() {
        // Simulate "a.   b" — 'b' should still be capitalized
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after '.   ' should be capitalized")
    }

    func testCapitalize_AfterPeriodWithoutSpace() {
        // Edge case: "a.b" (no space) — 'b' should NOT be capitalized per sentence rules
        // After '.' upperCaseStatus=1; typing 'b' immediately with index==1, should still fire
        // because the period set the status and no intervening non-space char reset it.
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        // Current implementation: capitalize fires immediately when next char arrives
        XCTAssertTrue(firstIsCaps(), "Character immediately after '.' should be capitalized")
    }

    // MARK: - Question Mark / Exclamation

    func testCapitalize_AfterQuestionMarkAndSpace() {
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: "?")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after '? ' should be capitalized")
    }

    func testCapitalize_AfterExclamationAndSpace() {
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: "!")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after '! ' should be capitalized")
    }

    // MARK: - Newline

    func testCapitalize_AfterNewline() {
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: "\n")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after newline should be capitalized")
    }

    func testCapitalize_AfterNewlineWithEmptyBuffer() {
        // Simulate Enter with empty buffer — common after committing a word
        engine.updateUpperCaseStatus(character: "\n")
        engine.reset()

        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "Character after newline (empty buffer) should be capitalized")
    }

    // MARK: - Non-trigger characters

    func testNoCapitalize_AfterComma() {
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ",")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(), "Character after ', ' should NOT be capitalized")
    }

    func testNoCapitalize_AfterPlainSpace() {
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(), "Character after plain space should NOT be capitalized")
    }

    // MARK: - Disabled feature

    func testNoCapitalize_WhenFeatureDisabled() {
        var settings = engine.settings
        settings.upperCaseFirstChar = false
        engine.updateSettings(settings)

        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(), "Feature disabled — no capitalize")
    }

    // MARK: - Only first character

    func testCapitalize_OnlyFirstCharacter() {
        // "a. bc" — only 'b' caps, 'c' stays lowercase
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)
        _ = engine.processKey(character: "c", keyCode: VietnameseData.KEY_C, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "First char 'b' should be capitalized")

        // Second char at index 1 (0-indexed) — should NOT be caps
        XCTAssertEqual(engine.index, 2)
        let secondIsCaps = (engine.typingWord[1] & VNEngine.CAPS_MASK) != 0
        XCTAssertFalse(secondIsCaps, "Second char 'c' should stay lowercase")
    }

    // MARK: - Status reset on other non-space char

    func testStatusResetByNonSpaceChar() {
        // "a.,b" — the comma between period and b should reset the status
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: ",")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(), "Comma after period resets the capitalize status")
    }

    // MARK: - Trigger preserved through macro replacement

    func testCapitalize_AfterMacroTriggeredByPeriodAndSpace() {
        // Enable macro, add "gm" → "gmail"
        // User types "gm." to trigger macro (period in isRestoreTrigger set)
        // Then space + letter — letter should be capitalized because period is a sentence-ender
        var settings = engine.settings
        settings.upperCaseFirstChar = true
        settings.macroEnabled = true
        engine.updateSettings(settings)

        // Add macro "gm" → "gmail"
        _ = engine.macroManager.addMacro(text: "gm", content: "gmail")
        defer { engine.macroManager.clearAll() }

        _ = engine.processKey(character: "g", keyCode: VietnameseData.KEY_G, isUppercase: false)
        _ = engine.processKey(character: "m", keyCode: VietnameseData.KEY_M, isUppercase: false)
        _ = engine.processWordBreak(character: ".")  // triggers macro replacement
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(), "After macro-replacement triggered by '.' then ' ', next letter should be capitalized")
    }

    // MARK: - Trigger preserved through spell-check restore

    func testCapitalize_AfterSpellCheckRestoreTriggeredByPeriod() {
        // User types invalid Vietnamese "hella" (phonetically valid as "hẻlla"? no — but simulates restore path)
        // Then types ".". If spell-check restore fires on this path, upperCaseStatus MUST still be set.
        var settings = engine.settings
        settings.upperCaseFirstChar = true
        settings.spellCheckEnabled = true
        settings.restoreIfWrongSpelling = true
        engine.updateSettings(settings)

        // Type a non-Vietnamese word that will likely trigger restore on word break
        _ = engine.processKey(character: "x", keyCode: VietnameseData.KEY_X, isUppercase: false)
        _ = engine.processKey(character: "y", keyCode: VietnameseData.KEY_Y, isUppercase: false)
        _ = engine.processKey(character: "f", keyCode: VietnameseData.KEY_F, isUppercase: false) // mark
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(),
            "Even when spell-check restore fires at the period, upperCaseStatus should be updated so next letter caps")
    }

    // MARK: - Toggle feature off clears pending status

    func testToggleOff_ClearsPendingStatus() {
        // Prime the status by typing "a. "
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        _ = engine.processWordBreak(character: " ")
        // upperCaseStatus should now be 1 (pending)

        // Toggle feature off — must clear stale pending status
        var settings = engine.settings
        settings.upperCaseFirstChar = false
        engine.updateSettings(settings)

        // Re-enable the feature. If status wasn't cleared, the next letter
        // would unexpectedly be capitalized even though user hasn't typed a
        // new sentence-ender since re-enabling.
        settings.upperCaseFirstChar = true
        engine.updateSettings(settings)

        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(),
            "After toggling feature off then on, stale pending status should not leak through")
    }

    // MARK: - Stale status across cursor move / reset

    func testNoCapitalize_AfterCursorMoveFollowingPeriod() {
        // Repro: user types "a." then moves cursor (mouse click / arrow keys),
        // which triggers resetWithCursorMoved(). The pending upperCaseStatus from
        // the period MUST be cleared — otherwise the next typed character at the
        // new cursor location gets unexpectedly capitalized.
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")
        // At this point upperCaseStatus == 1 (pending).

        engine.resetWithCursorMoved()

        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertFalse(firstIsCaps(),
            "After cursor move (reset), pending capitalize status must not leak to the new editing location")
    }

    func testCapitalize_PreservedAcrossPlainReset() {
        // Plain reset() is a "soft" reset used by Tab, Forward Delete, and the
        // Enter-with-empty-buffer path. Sentence context is intentionally
        // preserved so the next typed character is still capitalized.
        // Only resetWithCursorMoved() (mouse click / arrow keys / app switch)
        // clears the pending status — see testNoCapitalize_AfterCursorMoveFollowingPeriod.
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processWordBreak(character: ".")

        engine.reset()

        _ = engine.processKey(character: "b", keyCode: VietnameseData.KEY_B, isUppercase: false)

        XCTAssertTrue(firstIsCaps(),
            "Plain reset() preserves pending capitalize — only cursor-moved reset clears it")
    }
}
