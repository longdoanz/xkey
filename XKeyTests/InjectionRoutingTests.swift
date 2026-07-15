//
//  InjectionRoutingTests.swift
//  XKeyTests
//
//  Guards CharacterInjector.canRunSlowDirectAsync, the gate that decides whether an
//  injection may leave the event-tap callback. performSlowDirectInjection reproduces
//  only the plain `.slow` direct-post sequence, so any combination it cannot express
//  (proxy-bound methods, empty-char prefix, paste, Forward Delete) MUST stay on
//  injectSync. Letting one through would drop or corrupt keystrokes.
//

import XCTest
@testable import XKey

final class InjectionRoutingTests: XCTestCase {

    /// Records whether the needsForwardDelete autoclosure was evaluated.
    private final class Probe { var evaluated = false }

    private func canRunAsync(
        method: InjectionMethod = .slow,
        needsEmptyCharPrefix: Bool = false,
        textSendingMethod: TextSendingMethod = .oneByOne,
        backspaceCount: Int = 1,
        needsForwardDelete: Bool = false,
        probe: Probe? = nil
    ) -> Bool {
        CharacterInjector.canRunSlowDirectAsync(
            method: method,
            needsEmptyCharPrefix: needsEmptyCharPrefix,
            textSendingMethod: textSendingMethod,
            backspaceCount: backspaceCount,
            needsForwardDelete: {
                probe?.evaluated = true
                return needsForwardDelete
            }()
        )
    }

    // MARK: - Allowed: the exact subset performSlowDirectInjection can reproduce

    func testAllowsSlowOneByOne() {
        XCTAssertTrue(canRunAsync(textSendingMethod: .oneByOne))
    }

    func testAllowsSlowChunked() {
        XCTAssertTrue(canRunAsync(textSendingMethod: .chunked))
    }

    // MARK: - Rejected: everything the async path cannot express

    func testRejectsNonSlowMethods() {
        for method in InjectionMethod.allCases where method != .slow {
            XCTAssertFalse(
                canRunAsync(method: method),
                "\(method) may need a CGEventTapProxy and must stay synchronous"
            )
        }
    }

    func testRejectsEmptyCharPrefix() {
        XCTAssertFalse(
            canRunAsync(needsEmptyCharPrefix: true),
            "empty-char prefix is only implemented on the synchronous path"
        )
    }

    func testRejectsPaste() {
        XCTAssertFalse(
            canRunAsync(textSendingMethod: .paste),
            "paste needs pasteConfig and a proxy; performSlowDirectInjection asserts on it"
        )
    }

    func testRejectsForwardDeleteWhenBackspacing() {
        XCTAssertFalse(
            canRunAsync(backspaceCount: 1, needsForwardDelete: true),
            "the async path has no Forward Delete step, so a backspacing autocomplete app must stay sync"
        )
    }

    // MARK: - The Forward Delete check is expensive: keep it off the plain-insert path

    func testForwardDeleteCheckSkippedWhenNoBackspace() {
        let probe = Probe()
        let allowed = canRunAsync(backspaceCount: 0, needsForwardDelete: true, probe: probe)

        // injectSync wraps its whole Forward Delete step in `if backspaceCount > 0`, so with
        // no backspace the two paths are equivalent and the frontmost-app lookup is wasted.
        XCTAssertTrue(allowed, "a plain insert stays async even in an autocomplete app")
        XCTAssertFalse(probe.evaluated, "needsForwardDelete must not be resolved when backspaceCount == 0")
    }

    func testForwardDeleteCheckEvaluatedWhenBackspacing() {
        let probe = Probe()
        _ = canRunAsync(backspaceCount: 2, needsForwardDelete: false, probe: probe)
        XCTAssertTrue(probe.evaluated, "needsForwardDelete decides routing once a backspace is involved")
    }

    func testForwardDeleteCheckSkippedForRejectedMethod() {
        let probe = Probe()
        _ = canRunAsync(method: .axDirect, probe: probe)
        XCTAssertFalse(probe.evaluated, "cheap method checks must short-circuit before the app lookup")
    }
}
