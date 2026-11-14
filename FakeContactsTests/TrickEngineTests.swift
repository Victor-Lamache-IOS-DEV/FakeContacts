import XCTest
@testable import FakeContacts

final class TrickEngineTests: XCTestCase {
    private let storedKeys = [
        "trickArmed", "trickIndex", "trickMinSeconds",
        "searchTrickArmed", "searchTriggerDigits",
        "lastOpenedName", "lastOpenedPhone",
        "peekEnabled", "peekSoundEnabled", "peekHapticEnabled",
        "trickProfiles", "forcedContacts"
    ]

    override func setUp() {
        super.setUp()
        for key in storedKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private var twoProfiles: [TrickProfile] {
        [
            TrickProfile(fakePhone: "0600000001"),
            TrickProfile(fakePhone: "0600000002")
        ]
    }

    func testArmRequiresProfiles() {
        let engine = TrickEngine()

        engine.arm()

        XCTAssertFalse(engine.isArmed)
    }

    func testAdvanceMovesThroughProfilesThenDisarms() {
        let engine = TrickEngine()
        engine.profiles = twoProfiles
        engine.arm()

        XCTAssertTrue(engine.isArmed)
        XCTAssertEqual(engine.currentIndex, 0)

        engine.advance()
        XCTAssertEqual(engine.currentIndex, 1)

        engine.advance()
        XCTAssertFalse(engine.isArmed)
        XCTAssertEqual(engine.currentIndex, 0)
    }

    func testResetSequenceReturnsToFirstProfile() {
        let engine = TrickEngine()
        engine.profiles = twoProfiles
        engine.arm()
        engine.advance()

        engine.resetSequence()

        XCTAssertTrue(engine.isArmed)
        XCTAssertEqual(engine.currentIndex, 0)
    }

    func testActiveProfileIsNilWhenDisarmed() {
        let engine = TrickEngine()
        engine.profiles = twoProfiles

        XCTAssertNil(engine.activeProfile)
    }
}
