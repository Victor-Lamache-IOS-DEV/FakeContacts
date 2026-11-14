import XCTest
@testable import FakeContacts

final class FormattingTests: XCTestCase {
    func testLocalFrenchNumberIsGroupedInPairs() {
        XCTAssertEqual(formatPhone("0787797312"), "07 87 79 73 12")
    }

    func testInternationalFrenchNumber() {
        XCTAssertEqual(formatPhone("+33787797312"), "+33 7 87 79 73 12")
    }

    func testBirthdayWithYear() {
        let components = birthdayComponents(from: "15 / 03 / 1990")

        XCTAssertEqual(components?.day, 15)
        XCTAssertEqual(components?.month, 3)
        XCTAssertEqual(components?.year, 1990)
    }

    func testBirthdayWithoutYear() {
        let components = birthdayComponents(from: "15 / 03")

        XCTAssertEqual(components?.day, 15)
        XCTAssertEqual(components?.month, 3)
        XCTAssertNil(components?.year)
    }

    func testInvalidMonthIsRejected() {
        XCTAssertNil(birthdayComponents(from: "15 / 13"))
    }
}
