//
//  SecureInputStateMachineTests.swift
//  XKeyTests
//
//  Unit tests for the pure Secure Input decision logic.
//  No NSApplication and no real Secure Input holder required.
//

import XCTest
@testable import XKey

final class SecureInputStateMachineTests: XCTestCase {

    private let holderA: pid_t = 501
    private let holderB: pid_t = 602

    func testSecureInputHeldWhileVietnamese_showsOverlayAndLogs() {
        let old = SecureInputState(pid: 0, vietnamese: true)
        let new = SecureInputState(pid: holderA, vietnamese: true)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "1Password"),
            [.showOverlay(appName: "1Password"), .logHeld(appName: "1Password")]
        )
    }

    func testSecureInputHeldWhileEnglish_logsWithoutOverlay() {
        let old = SecureInputState(pid: 0, vietnamese: false)
        let new = SecureInputState(pid: holderA, vietnamese: false)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "1Password"),
            [.logHeld(appName: "1Password")]
        )
    }

    /// Regression: the old level-triggered code logged "Secure Input released"
    /// every time Vietnamese mode toggled while Secure Input was already off.
    func testTogglingVietnameseWhileSecureInputOff_doesNothing() {
        let old = SecureInputState(pid: 0, vietnamese: false)
        let new = SecureInputState(pid: 0, vietnamese: true)

        XCTAssertEqual(secureInputActions(from: old, to: new, appName: "Unknown"), [])
    }

    func testEnablingVietnameseWhileSecureInputHeld_showsOverlayWithoutRelogging() {
        let old = SecureInputState(pid: holderA, vietnamese: false)
        let new = SecureInputState(pid: holderA, vietnamese: true)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "1Password"),
            [.showOverlay(appName: "1Password")]
        )
    }

    func testDisablingVietnameseWhileSecureInputHeld_hidesOverlay() {
        let old = SecureInputState(pid: holderA, vietnamese: true)
        let new = SecureInputState(pid: holderA, vietnamese: false)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "1Password"),
            [.hideOverlay]
        )
    }

    func testSecureInputReleasedWhileVietnamese_hidesOverlayAndLogs() {
        let old = SecureInputState(pid: holderA, vietnamese: true)
        let new = SecureInputState(pid: 0, vietnamese: true)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "Unknown"),
            [.hideOverlay, .logReleased]
        )
    }

    func testHolderChanges_reshowsOverlayAndLogsNewHolder() {
        let old = SecureInputState(pid: holderA, vietnamese: true)
        let new = SecureInputState(pid: holderB, vietnamese: true)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "Terminal"),
            [.showOverlay(appName: "Terminal"), .logHeld(appName: "Terminal")]
        )
    }

    func testUnchangedState_doesNothing() {
        let state = SecureInputState(pid: holderA, vietnamese: true)

        XCTAssertEqual(secureInputActions(from: state, to: state, appName: "1Password"), [])
    }

    func testHolderChangesWhileVietnameseTurnsOff_hidesOverlayAndLogsNewHolder() {
        let old = SecureInputState(pid: holderA, vietnamese: true)
        let new = SecureInputState(pid: holderB, vietnamese: false)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "Terminal"),
            [.hideOverlay, .logHeld(appName: "Terminal")]
        )
    }

    /// Releasing while the engine is off is the common desync path: the poll stops in
    /// that mode, so the release is first observed later. Logging must still fire on its
    /// own, with no overlay action — the property that keeps logs decoupled from the overlay.
    func testSecureInputReleasedWhileEngineOff_logsWithoutOverlayAction() {
        let old = SecureInputState(pid: holderA, vietnamese: false)
        let new = SecureInputState(pid: 0, vietnamese: false)

        XCTAssertEqual(
            secureInputActions(from: old, to: new, appName: "Unknown"),
            [.logReleased]
        )
    }
}
