import XCTest
@testable import FakeContacts

final class ContactPresentationTests: XCTestCase {
    private func makeContact(isForced: Bool = false) -> Contact {
        Contact(
            id: "1",
            name: "Alice",
            phoneNumbers: [ContactField(label: "mobile", value: "0611223344")],
            emailAddresses: [ContactField(label: "home", value: "alice@example.com")],
            isForced: isForced
        )
    }

    func testNoProfileKeepsRealValues() {
        let presentation = ContactPresentation.resolve(contact: makeContact(), profile: nil)

        XCTAssertFalse(presentation.appliedTrick)
        XCTAssertEqual(presentation.phoneNumbers.map(\.value), ["0611223344"])
        XCTAssertEqual(presentation.emailAddresses.map(\.value), ["alice@example.com"])
    }

    func testActiveProfileOverridesPhoneAndEmail() {
        let profile = TrickProfile(fakePhone: "0700000000", fakeEmail: "fake@example.com")

        let presentation = ContactPresentation.resolve(contact: makeContact(), profile: profile)

        XCTAssertTrue(presentation.appliedTrick)
        XCTAssertEqual(presentation.phoneNumbers.map(\.value), ["0700000000"])
        XCTAssertEqual(presentation.emailAddresses.map(\.value), ["fake@example.com"])
    }

    func testEmptyProfileFieldsKeepRealValues() {
        let profile = TrickProfile(fakePhone: "  ", fakeEmail: "")

        let presentation = ContactPresentation.resolve(contact: makeContact(), profile: profile)

        XCTAssertTrue(presentation.appliedTrick)
        XCTAssertEqual(presentation.phoneNumbers.map(\.value), ["0611223344"])
        XCTAssertEqual(presentation.emailAddresses.map(\.value), ["alice@example.com"])
    }

    func testForcedContactIsNeverTricked() {
        let profile = TrickProfile(fakePhone: "0700000000")

        let presentation = ContactPresentation.resolve(
            contact: makeContact(isForced: true),
            profile: profile
        )

        XCTAssertFalse(presentation.appliedTrick)
        XCTAssertEqual(presentation.phoneNumbers.map(\.value), ["0611223344"])
    }
}
