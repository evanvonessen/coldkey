import XCTest
@testable import Coldkey

private final class FakeFunctionRowBackend: FunctionRowBackend {
    enum Failure: LocalizedError {
        case rejected
        var errorDescription: String? { "The setting was rejected." }
    }

    var mode = true
    var preference: Any? = true
    var modeReads = 0
    var modeWrites: [Bool] = []
    var preferenceReads = 0
    var preferenceWrites: [Any?] = []
    var failedModeReads: Set<Int> = []
    var failedModeWrites: Set<Int> = []
    var failedPreferenceReads: Set<Int> = []
    var failedPreferenceWrites: Set<Int> = []
    var ignoredModeWrites: Set<Int> = []
    var ignoredPreferenceWrites: Set<Int> = []
    var modeAfterPreferenceWrite: [Int: Bool] = [:]

    func readMode() throws -> Bool {
        modeReads += 1
        if failedModeReads.contains(modeReads) { throw Failure.rejected }
        return mode
    }

    func setMode(_ functionKeys: Bool) throws {
        modeWrites.append(functionKeys)
        if !ignoredModeWrites.contains(modeWrites.count) { mode = functionKeys }
        // Model native failures that occur after a partial change.
        if failedModeWrites.contains(modeWrites.count) { throw Failure.rejected }
    }

    func readPreference() throws -> Any? {
        preferenceReads += 1
        if failedPreferenceReads.contains(preferenceReads) { throw Failure.rejected }
        return preference
    }

    func setPreference(_ value: Any?) throws {
        preferenceWrites.append(value)
        if !ignoredPreferenceWrites.contains(preferenceWrites.count) { preference = value }
        if let refreshedMode = modeAfterPreferenceWrite[preferenceWrites.count] { mode = refreshedMode }
        if failedPreferenceWrites.contains(preferenceWrites.count) { throw Failure.rejected }
    }
}

final class FunctionRowControllerTests: XCTestCase {
    func testConstructionDoesNotReadOrChangeMacOSAndQueryOnlyReadsMode() throws {
        let backend = FakeFunctionRowBackend()
        let controller = FunctionRowController(backend: backend)
        XCTAssertEqual(backend.modeReads, 0)
        XCTAssertEqual(backend.preferenceReads, 0)
        XCTAssertTrue(try controller.isFunctionMode())
        backend.mode = false
        XCTAssertFalse(try controller.isFunctionMode())
        XCTAssertEqual(backend.modeReads, 2)
        XCTAssertTrue(backend.modeWrites.isEmpty)
        XCTAssertTrue(backend.preferenceWrites.isEmpty)
    }

    func testToggleSwitchesBothDirectionsAndSavesConfirmedMode() throws {
        let backend = FakeFunctionRowBackend()
        let controller = FunctionRowController(backend: backend)
        XCTAssertFalse(try controller.toggle())
        XCTAssertFalse(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, false)
        XCTAssertTrue(try controller.toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, true)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertEqual(backend.modeReads, 6)
        XCTAssertEqual(backend.preferenceReads, 4)
    }

    func testRuntimeModeWinsOverOldSavedPreference() throws {
        let backend = FakeFunctionRowBackend()
        backend.mode = false
        backend.preference = true
        XCTAssertTrue(try FunctionRowController(backend: backend).toggle())
        XCTAssertEqual(backend.modeWrites, [true])
        XCTAssertEqual(backend.preference as? Bool, true)
    }

    func testInitialReadFailuresNeverWriteEitherSetting() {
        for failPreference in [false, true] {
            let backend = FakeFunctionRowBackend()
            if failPreference { backend.failedPreferenceReads = [1] }
            else { backend.failedModeReads = [1] }
            XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
            XCTAssertTrue(backend.modeWrites.isEmpty)
            XCTAssertTrue(backend.preferenceWrites.isEmpty)
        }
    }

    func testPartialRuntimeWriteFailureRestoresModeWithoutChangingPreference() {
        let backend = FakeFunctionRowBackend()
        backend.failedModeWrites = [1]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertTrue(backend.preferenceWrites.isEmpty)
    }

    func testRuntimeVerificationFailureRestoresModeWithoutSavingPreference() {
        let backend = FakeFunctionRowBackend()
        backend.ignoredModeWrites = [1]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            guard case FunctionRowError.modeNotConfirmed = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertTrue(backend.preferenceWrites.isEmpty)
    }

    func testReadFailureAfterRuntimeChangeRestoresOriginalMode() {
        let backend = FakeFunctionRowBackend()
        backend.failedModeReads = [2]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertTrue(backend.preferenceWrites.isEmpty)
    }

    func testPartialPreferenceFailureRestoresRuntimeAndRemovesOriginallyAbsentPreference() {
        let backend = FakeFunctionRowBackend()
        backend.preference = nil
        backend.failedPreferenceWrites = [1]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertNil(backend.preference)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertEqual(backend.preferenceWrites.count, 2)
        XCTAssertEqual(backend.preferenceWrites[0] as? Bool, false)
        XCTAssertNil(backend.preferenceWrites[1])
    }

    func testUnconfirmedPreferenceRestoresExactOriginalValue() {
        let backend = FakeFunctionRowBackend()
        backend.preference = "original value"
        backend.ignoredPreferenceWrites = [1]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            guard case FunctionRowError.preferenceNotConfirmed = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.preference as? String, "original value")
        XCTAssertEqual(backend.preferenceWrites.count, 2)
        XCTAssertEqual(backend.preferenceWrites[1] as? String, "original value")
    }

    func testReadFailureAfterPreferenceChangeRestoresBothSettings() {
        let backend = FakeFunctionRowBackend()
        backend.failedPreferenceReads = [2]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, true)
        XCTAssertEqual(backend.preferenceWrites.count, 2)
    }

    func testPreferenceRefreshThatChangesRuntimeModeIsDetectedAndRolledBack() {
        let backend = FakeFunctionRowBackend()
        backend.modeAfterPreferenceWrite = [1: true, 2: false]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            guard case FunctionRowError.modeNotConfirmed = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, true)
        XCTAssertEqual(backend.modeWrites, [false, true])
        XCTAssertEqual(backend.preferenceWrites.count, 2)
    }

    func testFinalModeReadFailureRestoresBothSettings() {
        let backend = FakeFunctionRowBackend()
        backend.failedModeReads = [3]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle())
        XCTAssertTrue(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, true)
    }

    func testFailedModeRestorationStillRestoresPreferenceAndReportsUncertainty() {
        let backend = FakeFunctionRowBackend()
        backend.failedPreferenceWrites = [1]
        backend.failedModeWrites = [2]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            XCTAssertTrue(error.localizedDescription.contains("could not be fully restored"))
            XCTAssertTrue(error.localizedDescription.contains("The setting was rejected."))
        }
        XCTAssertEqual(backend.preference as? Bool, true)
        XCTAssertEqual(backend.preferenceWrites.count, 2)
    }

    func testFailedPreferenceRestorationIsReported() {
        let backend = FakeFunctionRowBackend()
        backend.failedPreferenceWrites = [1, 2]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            guard case FunctionRowError.restorationFailed = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(backend.mode)
    }

    func testUnconfirmedRuntimeRestorationIsReported() {
        let backend = FakeFunctionRowBackend()
        backend.failedPreferenceWrites = [1]
        backend.ignoredModeWrites = [2]
        XCTAssertThrowsError(try FunctionRowController(backend: backend).toggle()) { error in
            guard case FunctionRowError.restorationFailed = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertFalse(backend.mode)
        XCTAssertEqual(backend.preference as? Bool, true)
    }
}
