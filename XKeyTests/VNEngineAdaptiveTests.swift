//
//  VNEngineAdaptiveTests.swift
//  XKeyTests
//
//  Tests for the Adaptive input method (Telex + VNI auto-accept).
//

import XCTest
@testable import XKey

class VNEngineAdaptiveTests: XCTestCase {

    var engine: VNEngine!

    override func setUp() {
        super.setUp()
        engine = VNEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Task 1: enum + settings round-trip

    func testAdaptiveEnumExists() {
        XCTAssertEqual(InputMethod.adaptive.rawValue, 4)
        XCTAssertFalse(InputMethod.adaptive.displayName.isEmpty)
        XCTAssertTrue(InputMethod.allCases.contains(.adaptive))
    }

    func testAdaptiveSettingsRoundTrip() {
        var settings = engine.settings
        settings.inputMethod = .adaptive
        engine.updateSettings(settings)

        XCTAssertTrue(engine.vAdaptiveEnabled, "vAdaptiveEnabled should be set for .adaptive")
        XCTAssertEqual(engine.vInputType, 0, "base vInputType should default to Telex (0)")
        XCTAssertEqual(engine.settings.inputMethod, .adaptive, "reverse mapping should return .adaptive")
    }

    func testNonAdaptiveClearsFlag() {
        var settings = engine.settings
        settings.inputMethod = .adaptive
        engine.updateSettings(settings)
        XCTAssertTrue(engine.vAdaptiveEnabled)

        settings.inputMethod = .vni
        engine.updateSettings(settings)
        XCTAssertFalse(engine.vAdaptiveEnabled, "switching to VNI must clear vAdaptiveEnabled")
        XCTAssertEqual(engine.vInputType, 1)
        XCTAssertEqual(engine.settings.inputMethod, .vni)
    }

    // MARK: - Task 2: dual-typing produces the same Vietnamese output

    /// Helper: type a sequence of (character, keyCode) in adaptive mode and return the word.
    private func typeAdaptive(_ keys: [(Character, UInt16)]) -> String {
        engine.reset()
        engine.vAdaptiveEnabled = true
        engine.vInputType = 0
        for (ch, code) in keys {
            _ = engine.processKey(character: ch, keyCode: code, isUppercase: false)
        }
        return engine.getCurrentWord()
    }

    func testAdaptive_AcuteTone_BothWays() {
        // Telex: a + s  →  á
        XCTAssertEqual(typeAdaptive([("a", VietnameseData.KEY_A), ("s", VietnameseData.KEY_S)]), "á")
        // VNI: a + 1  →  á
        XCTAssertEqual(typeAdaptive([("a", VietnameseData.KEY_A), ("1", VietnameseData.KEY_1)]), "á")
    }

    func testAdaptive_Circumflex_BothWays() {
        // Telex: a + a  →  â
        XCTAssertEqual(typeAdaptive([("a", VietnameseData.KEY_A), ("a", VietnameseData.KEY_A)]), "â")
        // VNI: a + 6  →  â
        XCTAssertEqual(typeAdaptive([("a", VietnameseData.KEY_A), ("6", VietnameseData.KEY_6)]), "â")
    }

    func testAdaptive_Horn_U_BothWays() {
        // Telex: u + w  →  ư
        XCTAssertEqual(typeAdaptive([("u", VietnameseData.KEY_U), ("w", VietnameseData.KEY_W)]), "ư")
        // VNI: u + 7  →  ư
        XCTAssertEqual(typeAdaptive([("u", VietnameseData.KEY_U), ("7", VietnameseData.KEY_7)]), "ư")
    }

    func testAdaptive_Dee_BothWays() {
        // Telex: d + d  →  đ
        XCTAssertEqual(typeAdaptive([("d", VietnameseData.KEY_D), ("d", VietnameseData.KEY_D)]), "đ")
        // VNI: d + 9  →  đ
        XCTAssertEqual(typeAdaptive([("d", VietnameseData.KEY_D), ("9", VietnameseData.KEY_9)]), "đ")
    }

    // MARK: - Task 3: static gatekeepers accept adaptive keys

    func testAdaptive_DigitIsSpecialKey() {
        // Letters are always special; the point is digits must be special in adaptive.
        XCTAssertTrue(VNEngine.isVietnameseSpecialKey(character: "1", inputMethod: .adaptive))
        XCTAssertTrue(VNEngine.isVietnameseSpecialKey(character: "9", inputMethod: .adaptive))
        // Telex modifier letters too:
        XCTAssertTrue(VNEngine.isVietnameseSpecialKey(character: "s", inputMethod: .adaptive))
        // Brackets are Telex standalone input → special in adaptive:
        XCTAssertTrue(VNEngine.isVietnameseSpecialKey(character: "[", inputMethod: .adaptive))
        XCTAssertTrue(VNEngine.isVietnameseSpecialKey(character: "]", inputMethod: .adaptive))
    }

    func testAdaptive_BracketIsNotWordBreak() {
        // In Telex, [ and ] are NOT word breaks (they produce ơ/ư). Same for adaptive.
        XCTAssertFalse(VNEngine.isWordBreak(character: "[", inputMethod: .adaptive))
        XCTAssertFalse(VNEngine.isWordBreak(character: "]", inputMethod: .adaptive))
        // Space is always a word break:
        XCTAssertTrue(VNEngine.isWordBreak(character: " ", inputMethod: .adaptive))
    }

    // MARK: - Task 4: alphanumeric / English tokens stay literal

    func testAdaptive_CovidStaysLiteral() {
        let word = typeAdaptive([
            ("c", VietnameseData.KEY_C), ("o", VietnameseData.KEY_O), ("v", VietnameseData.KEY_V),
            ("i", VietnameseData.KEY_I), ("d", VietnameseData.KEY_D),
            ("1", VietnameseData.KEY_1), ("9", VietnameseData.KEY_9)
        ])
        XCTAssertEqual(word, "covid19", "non-Vietnamese token must not get VNI tones")
    }

    func testAdaptive_Mp3StaysLiteral() {
        let word = typeAdaptive([
            ("m", VietnameseData.KEY_M), ("p", VietnameseData.KEY_P), ("3", VietnameseData.KEY_3)
        ])
        XCTAssertEqual(word, "mp3", "all-consonant + digit token must not be modified")
    }

    func testAdaptive_ValidVietnameseDigitStillWorks() {
        // Sanity: a valid syllable + VNI digit still gets the tone (gate must not over-block).
        // v + i + 1 → ví
        XCTAssertEqual(typeAdaptive([
            ("v", VietnameseData.KEY_V), ("i", VietnameseData.KEY_I), ("1", VietnameseData.KEY_1)
        ]), "ví")
    }

    // MARK: - Task 5: full equivalence matrix + commit/backspace

    func testAdaptive_EquivalenceMatrix() {
        // (expected, telexKeys, vniKeys) — each pair must produce `expected` in adaptive mode.
        let cases: [(String, [(Character, UInt16)], [(Character, UInt16)])] = [
            ("á", [("a", VietnameseData.KEY_A), ("s", VietnameseData.KEY_S)],
                  [("a", VietnameseData.KEY_A), ("1", VietnameseData.KEY_1)]),
            ("à", [("a", VietnameseData.KEY_A), ("f", VietnameseData.KEY_F)],
                  [("a", VietnameseData.KEY_A), ("2", VietnameseData.KEY_2)]),
            ("â", [("a", VietnameseData.KEY_A), ("a", VietnameseData.KEY_A)],
                  [("a", VietnameseData.KEY_A), ("6", VietnameseData.KEY_6)]),
            ("ê", [("e", VietnameseData.KEY_E), ("e", VietnameseData.KEY_E)],
                  [("e", VietnameseData.KEY_E), ("6", VietnameseData.KEY_6)]),
            ("ô", [("o", VietnameseData.KEY_O), ("o", VietnameseData.KEY_O)],
                  [("o", VietnameseData.KEY_O), ("6", VietnameseData.KEY_6)]),
            ("ơ", [("o", VietnameseData.KEY_O), ("w", VietnameseData.KEY_W)],
                  [("o", VietnameseData.KEY_O), ("7", VietnameseData.KEY_7)]),
            ("ư", [("u", VietnameseData.KEY_U), ("w", VietnameseData.KEY_W)],
                  [("u", VietnameseData.KEY_U), ("7", VietnameseData.KEY_7)]),
            ("ă", [("a", VietnameseData.KEY_A), ("w", VietnameseData.KEY_W)],
                  [("a", VietnameseData.KEY_A), ("8", VietnameseData.KEY_8)]),
            ("đ", [("d", VietnameseData.KEY_D), ("d", VietnameseData.KEY_D)],
                  [("d", VietnameseData.KEY_D), ("9", VietnameseData.KEY_9)]),
        ]
        for (expected, telex, vni) in cases {
            XCTAssertEqual(typeAdaptive(telex), expected, "Telex path for \(expected)")
            XCTAssertEqual(typeAdaptive(vni), expected, "VNI path for \(expected)")
        }
    }

    func testAdaptive_WordBreakCommitsThenNewWord() {
        engine.reset()
        engine.vAdaptiveEnabled = true
        engine.vInputType = 0
        // Type "á" via VNI, commit with space, then start a fresh word via Telex.
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processKey(character: "1", keyCode: VietnameseData.KEY_1, isUppercase: false)
        XCTAssertEqual(engine.getCurrentWord(), "á")
        _ = engine.processWordBreak(character: " ")
        // New word "ô" via Telex
        _ = engine.processKey(character: "o", keyCode: VietnameseData.KEY_O, isUppercase: false)
        _ = engine.processKey(character: "o", keyCode: VietnameseData.KEY_O, isUppercase: false)
        XCTAssertEqual(engine.getCurrentWord(), "ô")
    }

    func testAdaptive_BackspaceClearsComposedChar() {
        engine.reset()
        engine.vAdaptiveEnabled = true
        engine.vInputType = 0
        // "á" via VNI a+1, then backspace removes the tone-bearing char.
        _ = engine.processKey(character: "a", keyCode: VietnameseData.KEY_A, isUppercase: false)
        _ = engine.processKey(character: "1", keyCode: VietnameseData.KEY_1, isUppercase: false)
        XCTAssertEqual(engine.getCurrentWord(), "á")
        _ = engine.processBackspace()
        XCTAssertEqual(engine.getCurrentWord(), "", "backspace should clear the single composed char")
    }

    // MARK: - Picker ordering + localization key

    func testAdaptive_IsFirstInAllCases() {
        // Pickers iterate InputMethod.allCases in declaration order, so adaptive
        // must be first to appear at the top of the list.
        XCTAssertEqual(InputMethod.allCases.first, .adaptive)
    }

    func testAdaptive_RawValueStableForPersistence() {
        // Reordering the declaration must NOT change the persisted rawValue.
        XCTAssertEqual(InputMethod.adaptive.rawValue, 4)
        XCTAssertEqual(InputMethod(rawValue: 4), .adaptive)
    }

    func testAdaptive_DisplayNameIsLocalizationSourceKey() {
        // displayName is used as the Localizable.xcstrings key (sourceLanguage = vi).
        XCTAssertEqual(InputMethod.adaptive.displayName, "Tự nhận kiểu gõ (Telex + VNI)")
    }

    // MARK: - Behavior edges

    func testAdaptive_MixedModifiers_VniThenTelex() {
        // a + 1 (VNI sắc → á) then f (Telex huyền) replaces the tone → à
        XCTAssertEqual(typeAdaptive([
            ("a", VietnameseData.KEY_A), ("1", VietnameseData.KEY_1), ("f", VietnameseData.KEY_F)
        ]), "à")
    }

    func testAdaptive_BracketComposesHornInAdaptive() {
        // Telex bracket standalone input must still work in adaptive: [ → ơ, ] → ư
        XCTAssertEqual(typeAdaptive([("[", VietnameseData.KEY_LEFT_BRACKET)]), "ơ")
        XCTAssertEqual(typeAdaptive([("]", VietnameseData.KEY_RIGHT_BRACKET)]), "ư")
    }

    func testAdaptive_Uppercase_BothWays() {
        // Uppercase Á via Telex (A+s) and VNI (A+1)
        func typeUpper(_ keys: [(Character, UInt16, Bool)]) -> String {
            engine.reset()
            engine.vAdaptiveEnabled = true
            engine.vInputType = 0
            for (ch, code, up) in keys {
                _ = engine.processKey(character: ch, keyCode: code, isUppercase: up)
            }
            return engine.getCurrentWord()
        }
        XCTAssertEqual(typeUpper([("A", VietnameseData.KEY_A, true), ("s", VietnameseData.KEY_S, false)]), "Á")
        XCTAssertEqual(typeUpper([("A", VietnameseData.KEY_A, true), ("1", VietnameseData.KEY_1, false)]), "Á")
    }

    // MARK: - English detection across the per-keystroke type flip

    func testAdaptive_VniMultiSyllable_NotEnglishDisabled() {
        // A full Vietnamese word typed entirely with VNI keys must compose correctly in
        // adaptive mode. vInputType reflects only the LAST keystroke, so when the trailing
        // letters ("n", "g") flip it back to Telex, the digit-bearing raw buffer must NOT
        // be validated against Telex tables alone and trip English detection.
        // tiếng via VNI: t i e 6(ê) 1(acute) n g
        XCTAssertEqual(typeAdaptive([
            ("t", VietnameseData.KEY_T), ("i", VietnameseData.KEY_I), ("e", VietnameseData.KEY_E),
            ("6", VietnameseData.KEY_6), ("1", VietnameseData.KEY_1),
            ("n", VietnameseData.KEY_N), ("g", VietnameseData.KEY_G)
        ]), "tiếng", "VNI-typed word must not be disabled as English in adaptive")
        // Cross-check: the Telex spelling of the same word yields the same result.
        // tiếng via Telex: t i e e(ê) s(acute) n g
        XCTAssertEqual(typeAdaptive([
            ("t", VietnameseData.KEY_T), ("i", VietnameseData.KEY_I), ("e", VietnameseData.KEY_E),
            ("e", VietnameseData.KEY_E), ("s", VietnameseData.KEY_S),
            ("n", VietnameseData.KEY_N), ("g", VietnameseData.KEY_G)
        ]), "tiếng")
    }

    func testAdaptive_EnglishWordStillDetectedLiteral() {
        // The both-tables check must not weaken English detection: "street" is impossible
        // under BOTH Telex and VNI, so it stays literal.
        XCTAssertEqual(typeAdaptive([
            ("s", VietnameseData.KEY_S), ("t", VietnameseData.KEY_T), ("r", VietnameseData.KEY_R),
            ("e", VietnameseData.KEY_E), ("e", VietnameseData.KEY_E), ("t", VietnameseData.KEY_T)
        ]), "street", "impossible-under-both token must remain literal")
    }

    // MARK: - VNI remove-tone key (0) in adaptive

    func testAdaptive_VniRemoveTone_0() {
        // VNI '0' strips the tone. As a digit it routes to VNI even in adaptive.
        // a + 1 (á) + 0 → a
        XCTAssertEqual(typeAdaptive([
            ("a", VietnameseData.KEY_A), ("1", VietnameseData.KEY_1), ("0", VietnameseData.KEY_0)
        ]), "a", "VNI '0' must strip a VNI-applied tone in adaptive")
    }

    func testAdaptive_VniRemoveTone_StripsTelexTone() {
        // Cross-convention: a Telex-applied tone removed by the VNI '0' key.
        // a + s (á, Telex) + 0 (VNI remove) → a
        XCTAssertEqual(typeAdaptive([
            ("a", VietnameseData.KEY_A), ("s", VietnameseData.KEY_S), ("0", VietnameseData.KEY_0)
        ]), "a", "VNI '0' must strip a Telex-applied tone in adaptive")
    }
}
