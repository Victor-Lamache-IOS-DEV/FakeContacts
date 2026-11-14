import XCTest
@testable import FakeContacts

final class ContactSearchTests: XCTestCase {
    private let alice = Contact(
        id: "1",
        name: "Alice",
        phoneNumbers: [ContactField(label: "mobile", value: "07 87 79 73 12")]
    )

    private let bob = Contact(
        id: "2",
        name: "Bob",
        phoneNumbers: [ContactField(label: "mobile", value: "06 11 22 33 44")]
    )

    private var sarah: Contact {
        Contact(
            id: "forced-sarah",
            name: "Sarah",
            phoneNumbers: [ContactField(label: "mobile", value: "0787")],
            isForced: true
        )
    }

    func testEmptyQueryReturnsAllContactsSortedByName() {
        let results = ContactSearch.results(
            contacts: [bob, alice],
            query: "",
            forcedContacts: [],
            triggerDigits: 4,
            searchTrickArmed: false
        )

        XCTAssertEqual(results.map(\.name), ["Alice", "Bob"])
    }

    func testTextQueryMatchesName() {
        let results = ContactSearch.results(
            contacts: [alice, bob],
            query: "ali",
            forcedContacts: [],
            triggerDigits: 4,
            searchTrickArmed: false
        )

        XCTAssertEqual(results.map(\.name), ["Alice"])
    }

    func testDigitQueryMatchesPhoneDigits() {
        let results = ContactSearch.results(
            contacts: [alice, bob],
            query: "0787",
            forcedContacts: [],
            triggerDigits: 4,
            searchTrickArmed: false
        )

        XCTAssertEqual(results.map(\.name), ["Alice"])
    }

    func testDisarmedTrickIgnoresForcedContacts() {
        let results = ContactSearch.results(
            contacts: [alice],
            query: "0787",
            forcedContacts: [sarah],
            triggerDigits: 4,
            searchTrickArmed: false
        )

        XCTAssertEqual(results.map(\.name), ["Alice"])
    }

    func testArmedTriggerLengthShowsOnlyForcedContacts() {
        let results = ContactSearch.results(
            contacts: [alice],
            query: "0787",
            forcedContacts: [sarah],
            triggerDigits: 4,
            searchTrickArmed: true
        )

        XCTAssertEqual(results.map(\.name), ["Sarah"])
    }

    func testArmedBelowTriggerLengthMixesRealAndForcedContacts() {
        let results = ContactSearch.results(
            contacts: [alice, bob],
            query: "07",
            forcedContacts: [sarah],
            triggerDigits: 4,
            searchTrickArmed: true
        )

        XCTAssertEqual(results.map(\.name), ["Alice", "Sarah"])
    }
}
