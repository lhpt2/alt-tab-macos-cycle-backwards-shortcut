import XCTest
@testable import SwitcherCore

final class CyclePassTests: XCTestCase {
    func testStepsAwayFromTheCurrentWindowAndWraps() {
        var pass = CyclePass(ids: [10, 20, 30], current: 10)
        XCTAssertEqual(pass.step(1), 20)
        XCTAssertEqual(pass.step(1), 30)
        XCTAssertEqual(pass.step(1), 10)
        XCTAssertEqual(pass.step(-1), 30)
    }

    func testBackwardFromTheCurrentWindowGoesToTheLast() {
        var pass = CyclePass(ids: [10, 20, 30], current: 10)
        XCTAssertEqual(pass.step(-1), 30)
    }

    func testWithoutACurrentWindowForwardStartsFirstAndBackwardLast() {
        var forward = CyclePass(ids: [10, 20, 30], current: 99)
        XCTAssertEqual(forward.step(1), 10)
        var backward = CyclePass(ids: [10, 20, 30], current: nil)
        XCTAssertEqual(backward.step(-1), 30)
    }

    func testEmptyPassSelectsNothing() {
        var pass = CyclePass(ids: [], current: nil)
        XCTAssertNil(pass.step(1))
    }
}

final class WindowOrderingTests: XCTestCase {
    private let windows = [
        WindowFacts(id: 3, appName: "Mail", title: "Inbox", lastFocus: nil, stackIndex: 1),
        WindowFacts(id: 1, appName: "Terminal", title: "zsh", lastFocus: 50, stackIndex: 0),
        WindowFacts(id: 2, appName: "Firefox", title: "Docs", lastFocus: 80, stackIndex: nil),
        WindowFacts(id: 4, appName: "Firefox", title: "Albums", lastFocus: nil, stackIndex: nil),
    ]

    func testRecentUsesFocusHistoryThenStacking() {
        XCTAssertEqual(WindowOrdering.sorted(windows, by: .recent).map(\.id), [2, 1, 3, 4])
    }

    func testCreatedIsOldestFirst() {
        XCTAssertEqual(WindowOrdering.sorted(windows, by: .created).map(\.id), [1, 2, 3, 4])
    }

    func testAlphabeticalIsByAppThenTitle() {
        XCTAssertEqual(WindowOrdering.sorted(windows, by: .alphabetical).map(\.id), [4, 2, 3, 1])
    }
}

final class ConfigTests: XCTestCase {
    func testDefaultConfigRoundTripsAndIsValid() throws {
        let config = try SwitcherConfig.decode(SwitcherConfig.default.encoded())
        XCTAssertEqual(config, SwitcherConfig.default)
        XCTAssertEqual(config.problems(), [])
    }

    func testABindingWithoutTheHoldModifiersIsReported() {
        let group = SwitcherGroup(hold: ["option"], forward: [KeyBinding(modifiers: ["cmd"], key: "tab")],
                                  backward: [], spaces: .all, order: .recent, instant: true)
        XCTAssertEqual(SwitcherConfig(groups: [group]).problems().count, 1)
    }

    func testModifierAliasesAreAccepted() {
        let group = SwitcherGroup(hold: ["alt"], forward: [KeyBinding(modifiers: ["⌥", "shift"], key: "tab")],
                                  backward: [], spaces: .current, order: .created, instant: false)
        XCTAssertEqual(SwitcherConfig(groups: [group]).problems(), [])
    }
}
