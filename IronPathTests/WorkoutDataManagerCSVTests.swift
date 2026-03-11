import Foundation
import XCTest
@testable import IronPath

@MainActor
final class WorkoutDataManagerCSVTests: XCTestCase {
    private let historyKey = "workout_history"
    private let updatedKey = "workout_history_updated"

    private var originalHistoryData: Data?
    private var originalUpdatedAt: Any?

    override func setUp() {
        super.setUp()
        originalHistoryData = UserDefaults.standard.data(forKey: historyKey)
        originalUpdatedAt = UserDefaults.standard.object(forKey: updatedKey)
    }

    override func tearDown() {
        if let originalHistoryData {
            UserDefaults.standard.set(originalHistoryData, forKey: historyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: historyKey)
        }

        if let originalUpdatedAt {
            UserDefaults.standard.set(originalUpdatedAt, forKey: updatedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: updatedKey)
        }

        super.tearDown()
    }

    func testExportHistoryAsCSV_PreservesWorkoutWeightUnitFormatting() {
        let workout = Workout(
            name: "Kg Workout",
            exercises: [
                WorkoutExercise(
                    exercise: TestData.dumbbellCurl,
                    sets: [
                        ExerciseSet(
                            setNumber: 1,
                            targetReps: 12,
                            actualReps: 12,
                            weight: 12.5,
                            completedAt: Date(timeIntervalSince1970: 1_700_200_000)
                        )
                    ],
                    orderIndex: 0
                )
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_200_000),
            weightUnit: .kilograms
        )

        CloudSyncManager.shared.saveWorkoutHistory([workout])

        let csv = WorkoutDataManager.shared.exportHistoryAsCSV()

        XCTAssertTrue(csv.contains("Weight Unit,Completed"))
        XCTAssertTrue(csv.contains(",12.5,N/A,N/A,kg,Yes"))
    }
}
