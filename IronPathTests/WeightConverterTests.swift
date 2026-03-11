import XCTest
@testable import IronPath

final class WeightConverterTests: XCTestCase {
    func testFormatOmitsDecimalForWholeNumbers() {
        XCTAssertEqual(
            WeightConverter.format(45, unit: .pounds, includeUnit: false),
            "45"
        )
    }

    func testFormatPreservesSingleDecimalIncrement() {
        XCTAssertEqual(
            WeightConverter.format(42.5, unit: .pounds, includeUnit: false),
            "42.5"
        )
    }

    func testFormatPreservesTwoDecimalIncrement() {
        XCTAssertEqual(
            WeightConverter.format(11.25, unit: .kilograms, includeUnit: false),
            "11.25"
        )
    }
}
