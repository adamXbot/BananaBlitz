import XCTest
@testable import BananaBlitz

final class SnapshotServiceTests: XCTestCase {

    func test_snapshotName_parsesTmutilOutput() {
        let output = """
        NOTE: local snapshots are considered purgeable and may be removed at any time by deleted(8).
        Created local snapshot with date: 2026-09-24-124007

        """
        XCTAssertEqual(SnapshotService.snapshotName(in: output), "2026-09-24-124007")
    }

    func test_snapshotName_isNilWhenTmutilReportsNoDate() {
        XCTAssertNil(SnapshotService.snapshotName(in: "tmutil: something went wrong"))
        XCTAssertNil(SnapshotService.snapshotName(in: ""))
    }
}
