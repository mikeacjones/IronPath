import SwiftUI

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to IronPath")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("AI-powered personalized workouts tailored to your goals, equipment, and fitness level")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Name Step

struct NameStep: View {
    @Binding var name: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.title)
                .fontWeight(.bold)

            TextField("Enter your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Gym Name Step

struct GymNameStep: View {
    @Binding var gymName: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Name your gym")
                .font(.title)
                .fontWeight(.bold)

            Text("You can add more gym profiles later for different locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("My Gym", text: $gymName)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Fitness Level Step

struct FitnessLevelStep: View {
    @Binding var fitnessLevel: FitnessLevel

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your fitness level?")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 15) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Button {
                        fitnessLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(level.rawValue)
                                .font(.headline)
                            Text(level.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(fitnessLevel == level ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Goals Step

struct GoalsStep: View {
    @Binding var selectedGoals: Set<FitnessGoal>

    var body: some View {
        VStack(spacing: 30) {
            Text("What are your goals?")
                .font(.title)
                .fontWeight(.bold)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack {
                            Text(goal.rawValue)
                                .font(.headline)
                            Spacer()
                            if selectedGoals.contains(goal) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(selectedGoals.contains(goal) ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Schedule Step

struct ScheduleStep: View {
    @Binding var workoutsPerWeek: Int
    @Binding var workoutDuration: Int

    var body: some View {
        VStack(spacing: 30) {
            Text("Your workout schedule")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                workoutsPerWeekSection
                workoutDurationSection
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var workoutsPerWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts per week")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { count in
                    Button {
                        workoutsPerWeek = count
                    } label: {
                        Text("\(count)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(width: 50, height: 50)
                            .background(workoutsPerWeek == count ? Color.blue : Color(.systemGray6))
                            .foregroundStyle(workoutsPerWeek == count ? .white : .primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var workoutDurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout duration")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach([30, 45, 60, 75, 90], id: \.self) { duration in
                    Button {
                        workoutDuration = duration
                    } label: {
                        HStack {
                            Text("\(duration) minutes")
                                .font(.headline)
                            Spacer()
                            if workoutDuration == duration {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(workoutDuration == duration ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
