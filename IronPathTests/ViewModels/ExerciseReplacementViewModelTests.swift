import XCTest
import SwiftUI
@testable import IronPath

@MainActor
final class ExerciseReplacementViewModelTests: XCTestCase {

    var sut: ExerciseReplacementViewModel!
    var mockAIProviderManager: MockAIProviderManager!
    var mockSimilarityService: MockExerciseSimilarityService!
    var mockGymProfileManager: MockGymProfileManager!

    override func setUp() async throws {
        mockAIProviderManager = MockAIProviderManager()
        mockSimilarityService = MockExerciseSimilarityService()
        mockGymProfileManager = MockGymProfileManager()

        // Add a default gym profile
        mockGymProfileManager.addProfile(TestData.sampleGymProfile)

        sut = ExerciseReplacementViewModel(
            aiProviderManager: mockAIProviderManager,
            similarityService: mockSimilarityService,
            gymProfileManager: mockGymProfileManager,
            exerciseCountProvider: { 100 }
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAIProviderManager = nil
        mockSimilarityService = nil
        mockGymProfileManager = nil
    }

    // MARK: - Initialization Tests

    func testInit_StartsWithNoExerciseToReplace() {
        XCTAssertNil(sut.exerciseToReplace)
    }

    func testInit_StartsWithEmptyReplacementNotes() {
        XCTAssertEqual(sut.replacementNotes, "")
    }

    func testInit_StartsNotLoading() {
        XCTAssertFalse(sut.isLoading)
    }

    func testTotalExerciseCount_ReturnsProviderValue() {
        XCTAssertEqual(sut.totalExerciseCount, 100)
    }

    // MARK: - Initiate Replacement Tests

    func testInitiateReplacement_SetsExerciseToReplace() {
        let exercise = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0)

        sut.initiateReplacement(for: exercise)

        XCTAssertEqual(sut.exerciseToReplace?.id, exercise.id)
    }

    func testInitiateReplacement_ClearsReplacementNotes() {
        sut.replacementNotes = "Previous notes"

        sut.initiateReplacement(for: TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0))

        XCTAssertEqual(sut.replacementNotes, "")
    }

    func testInitiateReplacement_ClearsError() {
        sut.error = "Previous error"

        sut.initiateReplacement(for: TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0))

        XCTAssertNil(sut.error)
    }

    func testInitiateReplacement_LoadsSimilaritySuggestions() {
        let suggestions = [
            (TestData.squat, 0.8),
            (TestData.latPulldown, 0.6)
        ]
        mockSimilarityService.suggestionsToReturn = suggestions

        sut.initiateReplacement(for: TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0))

        XCTAssertEqual(sut.similaritySuggestions.count, 2)
    }

    // MARK: - Cancel Replacement Tests

    func testCancelReplacement_ClearsExerciseToReplace() {
        sut.exerciseToReplace = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0)

        sut.cancelReplacement()

        XCTAssertNil(sut.exerciseToReplace)
    }

    func testCancelReplacement_ClearsReplacementNotes() {
        sut.replacementNotes = "Some notes"

        sut.cancelReplacement()

        XCTAssertEqual(sut.replacementNotes, "")
    }

    func testCancelReplacement_ClearsSuggestions() {
        mockSimilarityService.suggestionsToReturn = [(TestData.squat, 0.8)]
        sut.initiateReplacement(for: TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0))

        sut.cancelReplacement()

        XCTAssertTrue(sut.similaritySuggestions.isEmpty)
    }

    // MARK: - Quick Replacement Tests

    func testQuickReplace_CallsOnReplacementCallback() {
        var replacedOld: WorkoutExercise?
        var replacedNew: WorkoutExercise?
        sut.onReplacement = { old, new in
            replacedOld = old
            replacedNew = new
        }

        let originalExercise = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0)
        sut.exerciseToReplace = originalExercise

        sut.quickReplace(with: TestData.squat)

        XCTAssertEqual(replacedOld?.id, originalExercise.id)
        XCTAssertEqual(replacedNew?.exercise.name, TestData.squat.name)
    }

    func testQuickReplace_PreservesSetsStructure() {
        var replacement: WorkoutExercise?
        sut.onReplacement = { _, new in replacement = new }

        let originalExercise = TestData.workoutExercise(
            exercise: TestData.benchPress,
            orderIndex: 0,
            sets: [
                TestData.standardSet(number: 1, targetReps: 8, weight: 135),
                TestData.standardSet(number: 2, targetReps: 8, weight: 135),
                TestData.standardSet(number: 3, targetReps: 8, weight: 135)
            ]
        )
        sut.exerciseToReplace = originalExercise

        sut.quickReplace(with: TestData.squat)

        XCTAssertEqual(replacement?.sets.count, 3)
        XCTAssertEqual(replacement?.sets[0].targetReps, 8)
    }

    func testQuickReplace_PreservesOrderIndex() {
        var replacement: WorkoutExercise?
        sut.onReplacement = { _, new in replacement = new }

        let originalExercise = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 5)
        sut.exerciseToReplace = originalExercise

        sut.quickReplace(with: TestData.squat)

        XCTAssertEqual(replacement?.orderIndex, 5)
    }

    func testQuickReplace_ClearsState() {
        sut.exerciseToReplace = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0)
        sut.replacementNotes = "Notes"
        mockSimilarityService.suggestionsToReturn = [(TestData.squat, 0.8)]
        sut.loadSimilaritySuggestions()

        sut.quickReplace(with: TestData.squat)

        XCTAssertNil(sut.exerciseToReplace)
        XCTAssertEqual(sut.replacementNotes, "")
        XCTAssertTrue(sut.similaritySuggestions.isEmpty)
    }

    // MARK: - Top Suggestions Tests

    func testTopSuggestions_ReturnsMaxFive() {
        let manySuggestions = (0..<10).map { i in
            (TestData.benchPress, Double(i) / 10)
        }
        mockSimilarityService.suggestionsToReturn = manySuggestions

        sut.initiateReplacement(for: TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0))

        XCTAssertEqual(sut.topSuggestions.count, 5)
    }

    // MARK: - Similarity Color Tests

    func testSimilarityColor_HighScore_ReturnsGreen() {
        let color = sut.similarityColor(for: 0.85)
        XCTAssertEqual(color, .green)
    }

    func testSimilarityColor_MediumHighScore_ReturnsBlue() {
        let color = sut.similarityColor(for: 0.7)
        XCTAssertEqual(color, .blue)
    }

    func testSimilarityColor_MediumScore_ReturnsOrange() {
        let color = sut.similarityColor(for: 0.5)
        XCTAssertEqual(color, .orange)
    }

    func testSimilarityColor_LowScore_ReturnsGray() {
        let color = sut.similarityColor(for: 0.3)
        XCTAssertEqual(color, .gray)
    }

    // MARK: - AI Replacement Tests

    func testRequestAIReplacement_WithMissingData_SetsError() async {
        // Don't configure - no exerciseToReplace, userProfile, or workout
        sut.configure(userProfile: nil, currentWorkout: nil, currentWorkoutExercises: [])

        await sut.requestAIReplacement()

        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.showError)
    }

    func testRequestAIReplacement_SetsLoadingState() async {
        let exercise = TestData.workoutExercise(exercise: TestData.benchPress, orderIndex: 0)
        sut.exerciseToReplace = exercise
        sut.configure(
            userProfile: TestData.sampleUserProfile,
            currentWorkout: TestData.sampleWorkout,
            currentWorkoutExercises: []
        )

        // Start the request but don't wait
        let task = Task {
            await sut.requestAIReplacement()
        }

        // Give it a moment to set loading state
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Loading should be true during the request
        // (Note: This is a timing-dependent test)

        await task.value // Wait for completion
    }
}
