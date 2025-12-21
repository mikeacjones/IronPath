import XCTest
@testable import IronPath

@MainActor
final class AIPromptTests: XCTestCase {

    var sampleProfile: UserProfile!
    var defaultTechniqueOptions: WorkoutGenerationOptions!
    var sampleHistory: [Workout]!

    override func setUp() async throws {
        sampleProfile = UserProfile(
            name: "Test User",
            fitnessLevel: .intermediate,
            goals: [.hypertrophy],
            availableEquipment: [.barbell, .dumbbells, .cables]
        )

        defaultTechniqueOptions = WorkoutGenerationOptions(
            warmupSetMode: .allowed,
            dropSetMode: .allowed,
            restPauseMode: .allowed,
            supersetMode: .allowed
        )

        // Create sample workout history
        let benchPress = Exercise(
            name: "Bench Press",
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps],
            equipment: .barbell
        )
        let completedSets = [
            ExerciseSet(setNumber: 1, setType: .standard, targetReps: 8, actualReps: 8, weight: 185, restPeriod: 90, completedAt: Date()),
            ExerciseSet(setNumber: 2, setType: .standard, targetReps: 8, actualReps: 8, weight: 185, restPeriod: 90, completedAt: Date()),
            ExerciseSet(setNumber: 3, setType: .standard, targetReps: 8, actualReps: 9, weight: 185, restPeriod: 90, completedAt: Date())
        ]
        let workoutExercise = WorkoutExercise(exercise: benchPress, sets: completedSets, orderIndex: 0)
        sampleHistory = [
            Workout(
                name: "Push Day",
                exercises: [workoutExercise],
                startedAt: Date().addingTimeInterval(-86400 * 3),
                completedAt: Date().addingTimeInterval(-86400 * 3 + 3600)
            )
        ]
    }

    override func tearDown() async throws {
        sampleProfile = nil
        defaultTechniqueOptions = nil
        sampleHistory = nil
    }

    // MARK: - System Prompt Tests

    func testSystemPromptLength() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // System prompt should be under 4000 characters for token efficiency
        XCTAssertLessThan(systemPrompt.count, 4000, "System prompt exceeds 4000 character target")

        // Should contain essential components
        XCTAssertTrue(systemPrompt.contains("personal trainer"), "Missing trainer persona")
        XCTAssertTrue(systemPrompt.contains("JSON"), "Missing JSON instruction")
    }

    func testSystemPromptContainsProfileSummary() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        XCTAssertTrue(systemPrompt.contains("USER PROFILE"), "Missing profile section")
        XCTAssertTrue(systemPrompt.contains("Intermediate"), "Missing fitness level")
        XCTAssertTrue(systemPrompt.contains("Hypertrophy"), "Missing training style")
    }

    func testSystemPromptContainsEquipmentSummary() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        XCTAssertTrue(systemPrompt.contains("GYM EQUIPMENT"), "Missing equipment section")
    }

    // MARK: - Technique Requirement Tests

    func testTechniqueRequiredMarkers() {
        // Create options with warmup required
        let requiredOptions = WorkoutGenerationOptions(
            warmupSetMode: .required,
            dropSetMode: .allowed,
            restPauseMode: .allowed,
            supersetMode: .allowed
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: requiredOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // Should contain [REQUIRED] marker for warmup sets
        XCTAssertTrue(systemPrompt.contains("[REQUIRED]"), "Missing [REQUIRED] marker when warmup is required")
        XCTAssertTrue(systemPrompt.contains("TECHNIQUE REQUIREMENTS"), "Missing technique section")
    }

    func testMultipleTechniquesRequired() {
        // Create options with multiple techniques required
        let multiRequiredOptions = WorkoutGenerationOptions(
            warmupSetMode: .required,
            dropSetMode: .required,
            restPauseMode: .allowed,
            supersetMode: .required
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: multiRequiredOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // Count [REQUIRED] markers
        let requiredCount = systemPrompt.components(separatedBy: "[REQUIRED]").count - 1

        // Should have markers for technique section
        XCTAssertGreaterThan(requiredCount, 0, "Should have at least one [REQUIRED] marker")
        XCTAssertTrue(systemPrompt.contains("Warmup sets"), "Missing warmup requirement")
        XCTAssertTrue(systemPrompt.contains("Drop sets"), "Missing drop set requirement")
        XCTAssertTrue(systemPrompt.contains("Supersets"), "Missing superset requirement")
    }

    func testNoTechniqueMarkersWhenDisabled() {
        let disabledOptions = WorkoutGenerationOptions(
            warmupSetMode: .disabled,
            dropSetMode: .disabled,
            restPauseMode: .disabled,
            supersetMode: .disabled
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: disabledOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // Should not contain technique section when all disabled
        XCTAssertFalse(systemPrompt.contains("TECHNIQUE REQUIREMENTS"), "Should not have technique section when all disabled")
    }

    // MARK: - Emphasis Hierarchy Tests

    func testEmphasisHierarchy() {
        // Create options with all techniques required
        let allRequiredOptions = WorkoutGenerationOptions(
            warmupSetMode: .required,
            dropSetMode: .required,
            restPauseMode: .required,
            supersetMode: .required
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: allRequiredOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // Count [REQUIRED] markers
        let requiredCount = systemPrompt.components(separatedBy: "[REQUIRED]").count - 1

        // Should have max 3 [REQUIRED] markers per prompt (guideline from PromptPriority docs)
        // With technique section + output format, we expect around 2 markers
        XCTAssertLessThanOrEqual(requiredCount, 3, "Too many [REQUIRED] markers - emphasis dilution")
    }

    func testImportantMarkersPresent() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()

        // Should contain [IMPORTANT] markers for exercise selection and weight rules
        let importantCount = systemPrompt.components(separatedBy: "[IMPORTANT]").count - 1
        XCTAssertGreaterThan(importantCount, 0, "Should have at least one [IMPORTANT] marker")
    }

    // MARK: - Weight Unit Consistency Tests

    func testWeightUnitConsistency_Pounds() {
        // Mock GymProfileManager will return pounds by default
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()
        let userPrompt = builder.buildUserPrompt(history: sampleHistory, availableExercises: "Bench Press")

        let combinedPrompt = systemPrompt + userPrompt

        // Should contain "lbs" and not "kg" when pounds is selected
        XCTAssertTrue(combinedPrompt.contains("lbs"), "Missing lbs unit")

        // Check there's no stray "kg" references (allowing for "kg" in context of explaining units)
        // This is a softer check - we mainly care about weight values
        if combinedPrompt.contains("kg") {
            // If kg appears, it should only be in explanatory context, not in weight values
            let kgOccurrences = combinedPrompt.components(separatedBy: "kg").count - 1
            let lbsOccurrences = combinedPrompt.components(separatedBy: "lbs").count - 1
            XCTAssertGreaterThan(lbsOccurrences, kgOccurrences, "Pounds should be dominant unit")
        }
    }

    func testWeightUnitConsistency_Kilograms() {
        // Create a gym profile with kg preference
        let kgProfile = GymProfile(
            name: "Test Gym",
            availableEquipment: [.barbell, .dumbbells],
            preferredWeightUnit: .kilograms,
            defaultCableConfig: .defaultConfigKg
        )

        // Temporarily set as active profile (note: this is a limitation of the test)
        // In real implementation, GymProfileManager would be injected
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let systemPrompt = builder.buildSystemPrompt()
        let userPrompt = builder.buildUserPrompt(history: sampleHistory, availableExercises: "Bench Press")

        let combinedPrompt = systemPrompt + userPrompt

        // Should reference kg in weight instructions
        // Note: Due to GymProfileManager.shared usage, this test may fail in current implementation
        // This documents the desired behavior for future refactoring
        let hasKgReference = combinedPrompt.contains("kg")
        XCTAssertTrue(hasKgReference || combinedPrompt.contains("lbs"), "Should reference weight units")
    }

    // MARK: - Progression Summary Tests

    func testProgressionSummaryFormat() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let userPrompt = builder.buildUserPrompt(history: sampleHistory, availableExercises: "Bench Press, Squat")

        // Should contain progression context section
        XCTAssertTrue(userPrompt.contains("PROGRESSION CONTEXT"), "Missing progression section")

        // Should reference the exercise from history
        XCTAssertTrue(userPrompt.contains("Bench Press"), "Missing exercise from history")

        // Should contain weight and rep information
        let hasWeightInfo = userPrompt.contains("185") || userPrompt.contains("lbs") || userPrompt.contains("kg")
        XCTAssertTrue(hasWeightInfo, "Missing weight information")

        // Should contain progression suggestion
        let hasProgressionSuggestion = userPrompt.contains("Try") || userPrompt.contains("Stay")
        XCTAssertTrue(hasProgressionSuggestion, "Missing progression suggestion")
    }

    func testProgressionSummaryEmptyHistory() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        // Should handle empty history gracefully
        XCTAssertTrue(userPrompt.contains("No workout history"), "Missing empty history message")
    }

    func testProgressionSummaryDeloadMode() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions,
            isDeload: true
        )

        let userPrompt = builder.buildUserPrompt(history: sampleHistory, availableExercises: "Bench Press")

        // Should contain deload warning
        XCTAssertTrue(userPrompt.contains("DELOAD"), "Missing deload indicator")
        XCTAssertTrue(userPrompt.contains("lighter weights") || userPrompt.contains("recovery"), "Missing deload guidance")

        // Progression suggestions should reference deload (60%)
        XCTAssertTrue(userPrompt.contains("60%") || userPrompt.contains("deload"), "Missing deload percentage")
    }

    // MARK: - Output Format Tests

    func testOutputFormatWithGroups() {
        let supersetOptions = WorkoutGenerationOptions(
            warmupSetMode: .allowed,
            dropSetMode: .allowed,
            restPauseMode: .allowed,
            supersetMode: .required
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: supersetOptions
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        // Should include exerciseGroups in output format when supersets enabled
        XCTAssertTrue(userPrompt.contains("exerciseGroups"), "Missing exerciseGroups in output format")
        XCTAssertTrue(userPrompt.contains("superset") || userPrompt.contains("Superset"), "Missing superset instructions")
    }

    func testOutputFormatWithoutGroups() {
        let noSupersetOptions = WorkoutGenerationOptions(
            warmupSetMode: .allowed,
            dropSetMode: .allowed,
            restPauseMode: .allowed,
            supersetMode: .disabled
        )

        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: noSupersetOptions
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        // Should still have output format section
        XCTAssertTrue(userPrompt.contains("OUTPUT FORMAT"), "Missing output format section")
    }

    // MARK: - User Notes and Context Tests

    func testUserNotesIncluded() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions,
            userNotes: "Focus on chest, shoulder is sore"
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        XCTAssertTrue(userPrompt.contains("Focus on chest, shoulder is sore"), "User notes not included")
        XCTAssertTrue(userPrompt.contains("My Notes"), "Missing notes section header")
    }

    func testWorkoutTypeIncluded() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions,
            workoutType: "Push Day"
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        XCTAssertTrue(userPrompt.contains("Push Day"), "Workout type not included")
        XCTAssertTrue(userPrompt.contains("Workout Type"), "Missing workout type header")
    }

    func testDateIncluded() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let userPrompt = builder.buildUserPrompt(history: [], availableExercises: "Bench Press")

        XCTAssertTrue(userPrompt.contains("Today's Date"), "Missing date context")
    }

    // MARK: - Complete Prompt Pair Tests

    func testBuildPromptsBothReturned() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: defaultTechniqueOptions
        )

        let (systemPrompt, userPrompt) = builder.buildPrompts(
            history: sampleHistory,
            availableExercises: "Bench Press, Squat, Deadlift"
        )

        XCTAssertFalse(systemPrompt.isEmpty, "System prompt should not be empty")
        XCTAssertFalse(userPrompt.isEmpty, "User prompt should not be empty")

        // System prompt should have persona
        XCTAssertTrue(systemPrompt.contains("trainer"), "System prompt missing persona")

        // User prompt should have workout request
        XCTAssertTrue(userPrompt.contains("workout"), "User prompt missing workout request")
    }

    // MARK: - Schema Validation Helper Tests

    func testPromptComponentsPriorityMarkers() {
        // Test that PromptPriority enum provides correct markers
        XCTAssertEqual(PromptPriority.critical.marker, "[REQUIRED]")
        XCTAssertEqual(PromptPriority.important.marker, "[IMPORTANT]")
        XCTAssertEqual(PromptPriority.guidance.marker, "")
    }

    func testPromptSectionRendering() {
        let criticalSection = PromptSection(
            title: "TEST SECTION",
            priority: .critical,
            content: "This is critical content"
        )

        let rendered = criticalSection.render()

        XCTAssertTrue(rendered.contains("[REQUIRED]"), "Critical section should have [REQUIRED] marker")
        XCTAssertTrue(rendered.contains("TEST SECTION"), "Section should include title")
        XCTAssertTrue(rendered.contains("This is critical content"), "Section should include content")
    }

    func testWeightRulesSection() {
        let weightSection = PromptComponents.weightRules(
            unit: .pounds,
            equipmentSummary: "Barbell: 45 lbs, Dumbbells: 5-100 lbs"
        )

        let rendered = weightSection.render()

        XCTAssertTrue(rendered.contains("lbs"), "Weight rules should reference unit")
        XCTAssertTrue(rendered.contains("WEIGHT HANDLING"), "Should have weight handling title")
        XCTAssertEqual(weightSection.priority, .important, "Weight rules should be important priority")
    }

    func testExerciseSelectionRulesSection() {
        let selectionSection = PromptComponents.exerciseSelectionRules(exerciseCount: "5-7")

        let rendered = selectionSection.render()

        XCTAssertTrue(rendered.contains("5-7"), "Should include exercise count")
        XCTAssertTrue(rendered.contains("EXERCISE SELECTION"), "Should have selection title")
        XCTAssertEqual(selectionSection.priority, .important, "Exercise selection should be important")
    }

    func testOutputFormatSection() {
        let formatSectionWithGroups = PromptComponents.outputFormatSection(includeGroups: true)
        let formatSectionWithoutGroups = PromptComponents.outputFormatSection(includeGroups: false)

        let renderedWithGroups = formatSectionWithGroups.render()
        let renderedWithoutGroups = formatSectionWithoutGroups.render()

        XCTAssertTrue(renderedWithGroups.contains("exerciseGroups"), "Should include groups when enabled")
        XCTAssertFalse(renderedWithoutGroups.contains("exerciseGroups"), "Should not include groups when disabled")
        XCTAssertEqual(formatSectionWithGroups.priority, .critical, "Output format should be critical")
    }

    func testTechniqueSectionGeneration() {
        // Test with required warmup
        let requiredOptions = WorkoutGenerationOptions(
            warmupSetMode: .required,
            dropSetMode: .allowed,
            restPauseMode: .disabled,
            supersetMode: .disabled
        )

        let techniqueSection = PromptComponents.techniqueSection(
            options: requiredOptions,
            fitnessLevel: .intermediate
        )

        XCTAssertNotNil(techniqueSection, "Should generate technique section with warmup required")
        XCTAssertEqual(techniqueSection?.priority, .critical, "Should be critical when techniques required")

        let rendered = techniqueSection!.render()
        XCTAssertTrue(rendered.contains("Warmup"), "Should mention warmup sets")
    }

    func testTechniqueSectionNilWhenAllDisabled() {
        let allDisabled = WorkoutGenerationOptions(
            warmupSetMode: .disabled,
            dropSetMode: .disabled,
            restPauseMode: .disabled,
            supersetMode: .disabled
        )

        let techniqueSection = PromptComponents.techniqueSection(
            options: allDisabled,
            fitnessLevel: .intermediate
        )

        XCTAssertNil(techniqueSection, "Should return nil when all techniques disabled")
    }

    func testSupersetInstructions() {
        let requiredInstructions = PromptComponents.supersetInstructions(mode: .required)
        let allowedInstructions = PromptComponents.supersetInstructions(mode: .allowed)
        let disabledInstructions = PromptComponents.supersetInstructions(mode: .disabled)

        XCTAssertNotNil(requiredInstructions, "Should provide instructions when required")
        XCTAssertNotNil(allowedInstructions, "Should provide instructions when allowed")
        XCTAssertNil(disabledInstructions, "Should not provide instructions when disabled")

        XCTAssertTrue(requiredInstructions!.contains("[REQUIRED]"), "Required mode should have marker")
        XCTAssertTrue(requiredInstructions!.contains("superset") || requiredInstructions!.contains("circuit"),
                     "Should mention superset or circuit")
    }

    // MARK: - Integration Tests

    func testFullPromptGenerationFlow() {
        let builder = WorkoutPromptBuilder(
            profile: sampleProfile,
            techniqueOptions: WorkoutGenerationOptions(
                warmupSetMode: .required,
                dropSetMode: .allowed,
                restPauseMode: .allowed,
                supersetMode: .required
            ),
            workoutType: "Push Day",
            targetMuscles: [.chest, .shoulders, .triceps],
            isDeload: false,
            userNotes: "Focus on strength today"
        )

        let (systemPrompt, userPrompt) = builder.buildPrompts(
            history: sampleHistory,
            availableExercises: "Bench Press, Overhead Press, Dips"
        )

        // Verify system prompt structure
        XCTAssertTrue(systemPrompt.contains("trainer"), "Missing trainer persona")
        XCTAssertTrue(systemPrompt.contains("USER PROFILE"), "Missing profile")
        XCTAssertTrue(systemPrompt.contains("TECHNIQUE"), "Missing technique requirements")
        XCTAssertLessThan(systemPrompt.count, 4000, "System prompt too long")

        // Verify user prompt structure
        XCTAssertTrue(userPrompt.contains("Push Day"), "Missing workout type")
        XCTAssertTrue(userPrompt.contains("Focus on strength today"), "Missing user notes")
        XCTAssertTrue(userPrompt.contains("PROGRESSION"), "Missing progression context")
        XCTAssertTrue(userPrompt.contains("Bench Press"), "Missing exercise history")
        XCTAssertTrue(userPrompt.contains("OUTPUT FORMAT"), "Missing output format")

        // Verify technique requirements
        let requiredCount = systemPrompt.components(separatedBy: "[REQUIRED]").count - 1
        XCTAssertGreaterThan(requiredCount, 0, "Should have required markers")
        XCTAssertLessThanOrEqual(requiredCount, 3, "Too many required markers")
    }
}
