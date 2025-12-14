import Foundation

/// Static exercise database with common exercises
@MainActor
final class ExerciseDatabase {
    static let shared = ExerciseDatabase()

    private init() {}

    /// All available exercises
    lazy var exercises: [Exercise] = {
        return chestExercises + backExercises + shoulderExercises + bicepExercises +
               tricepExercises + legExercises + coreExercises + trapBarExercises +
               medicineBallExercises
    }()

    // MARK: - Chest Exercises

    let chestExercises: [Exercise] = [
        Exercise(
            name: "Barbell Bench Press",
            alternateNames: ["Flat Bench", "Bench Press", "Flat Barbell Press", "BB Bench"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Lie on a flat bench, grip the bar slightly wider than shoulder width. Lower to chest, press up.",
            formTips: "Keep your feet flat, back slightly arched, and squeeze your shoulder blades together.",
            videoURL: "https://www.youtube.com/watch?v=rT7DgCr-3pg",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Dumbbell Bench Press",
            alternateNames: ["Flat DB Press", "DB Bench", "Dumbbell Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Lie on a flat bench with dumbbells at chest level. Press up and together.",
            formTips: "Don't let the dumbbells drift too far apart at the bottom. Control the descent.",
            videoURL: "https://www.youtube.com/watch?v=VmB1G1K7v94",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Incline Dumbbell Press",
            alternateNames: ["Incline DB Press", "Incline Press", "Upper Chest Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.shoulders, .triceps],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Set bench to 30-45 degrees. Press dumbbells up from shoulder level.",
            formTips: "Focus on the upper chest. Don't set the incline too high or shoulders take over.",
            videoURL: "https://www.youtube.com/watch?v=8iPEnn-ltC8",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Cable Flyes",
            alternateNames: ["Cable Fly", "Cable Crossover", "Standing Cable Fly"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Stand between cable towers, bring handles together in front of chest with slight elbow bend.",
            formTips: "Keep a slight bend in your elbows throughout. Squeeze at the peak contraction.",
            videoURL: "https://www.youtube.com/watch?v=Iwe6AmxVf7o",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Push-Ups",
            alternateNames: ["Pushups", "Press-Ups", "Floor Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Hands shoulder-width apart, lower chest to ground, push back up.",
            formTips: "Keep your body in a straight line. Don't let hips sag or pike up.",
            videoURL: "https://www.youtube.com/watch?v=IODxDxX7oi4",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Dumbbell Flyes",
            alternateNames: ["DB Flyes", "Flat Flyes", "Chest Flyes"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Lie on bench, extend arms above chest, lower out to sides with slight elbow bend.",
            formTips: "Don't go too deep - stop when you feel a stretch. Keep the motion controlled.",
            videoURL: "https://www.youtube.com/watch?v=eozdVDA78K0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Decline Bench Press",
            alternateNames: ["Decline Barbell Press", "Decline Press", "Lower Chest Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Lie on decline bench, lower bar to lower chest, press up.",
            formTips: "Targets lower chest. Use a spotter or safety bars.",
            videoURL: "https://www.youtube.com/watch?v=LfyQBUKR8SE",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Incline Barbell Bench Press",
            alternateNames: ["Incline Bench", "Incline BB Press", "Incline Barbell Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.shoulders, .triceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Set bench to 30-45 degrees, lower bar to upper chest, press up.",
            formTips: "Grip slightly wider than shoulder width. Focus on upper chest contraction.",
            videoURL: "https://www.youtube.com/watch?v=SrqOu55lrYU",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Pec Deck",
            alternateNames: ["Pec Fly Machine", "Butterfly Machine", "Chest Fly Machine"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            specificMachine: .pecDeck,
            difficulty: .beginner,
            instructions: "Sit at machine with arms on pads, bring arms together in front of chest.",
            formTips: "Keep slight bend in elbows. Squeeze at the peak contraction.",
            videoURL: "https://www.youtube.com/watch?v=Z57CtFmRMxA",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Low Cable Crossover",
            alternateNames: ["Low to High Cable Fly", "Low Cable Fly", "Upward Cable Fly"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.shoulders],
            equipment: .cables,
            difficulty: .intermediate,
            instructions: "Set cables low, bring handles up and together at chest level.",
            formTips: "Targets upper chest. Keep slight bend in elbows throughout.",
            videoURL: "https://www.youtube.com/watch?v=taI4XduLpTk",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Machine Chest Press",
            alternateNames: ["Chest Press Machine", "Seated Chest Press", "Hammer Strength Chest Press"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders],
            equipment: .bodyweightOnly,
            specificMachine: .chestPress,
            difficulty: .beginner,
            instructions: "Sit at machine, press handles forward until arms are extended.",
            formTips: "Good for beginners or burnout sets. Keep back against pad.",
            videoURL: "https://www.youtube.com/watch?v=xUm0BiZCWlQ",
            movementPattern: .horizontalPush
        )
    ]

    // MARK: - Back Exercises

    let backExercises: [Exercise] = [
        Exercise(
            name: "Pull-Ups",
            alternateNames: ["Pullups", "Wide Grip Pull-Up", "Overhand Pull-Up"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .pullUpBar,
            difficulty: .intermediate,
            instructions: "Hang from bar with overhand grip, pull up until chin clears bar.",
            formTips: "Initiate the pull with your back, not your arms. Avoid swinging.",
            videoURL: "https://www.youtube.com/watch?v=eGo4IYlbE5g",
            movementPattern: .verticalPull
        ),
        Exercise(
            name: "Lat Pulldown",
            alternateNames: ["Lat Pull Down", "Wide Grip Pulldown", "Cable Pulldown"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Sit at lat pulldown machine, pull bar to upper chest.",
            formTips: "Lean back slightly, pull with your elbows, squeeze shoulder blades together.",
            videoURL: "https://www.youtube.com/watch?v=CAwf7n6Luuc",
            movementPattern: .verticalPull
        ),
        Exercise(
            name: "Barbell Row",
            alternateNames: ["Bent Over Row", "BB Row", "Bent Over Barbell Row"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps, .lowerBack],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Bend at hips, back flat, pull barbell to lower chest/upper abs.",
            formTips: "Keep your back flat and core tight. Don't use momentum.",
            videoURL: "https://www.youtube.com/watch?v=FWJR5Ve8bnQ",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Dumbbell Row",
            alternateNames: ["DB Row", "One Arm Row", "Single Arm Dumbbell Row"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "One hand and knee on bench, row dumbbell to hip with other arm.",
            formTips: "Keep your back flat. Pull to your hip, not your shoulder.",
            videoURL: "https://www.youtube.com/watch?v=pYcpY20QaE8",
            movementPattern: .horizontalPull,
            isUnilateral: true
        ),
        Exercise(
            name: "Seated Cable Row",
            alternateNames: ["Cable Row", "Low Row", "Seated Row"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Sit at cable row, pull handle to stomach while keeping back straight.",
            formTips: "Don't lean too far back. Squeeze your shoulder blades at the end.",
            videoURL: "https://www.youtube.com/watch?v=GZbfZ033f74",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Deadlift",
            alternateNames: ["Conventional Deadlift", "Barbell Deadlift", "DL"],
            primaryMuscleGroups: [.back, .hamstrings, .glutes],
            secondaryMuscleGroups: [.lowerBack, .traps],
            equipment: .barbell,
            difficulty: .advanced,
            instructions: "Stand with feet hip-width, grip bar, drive through heels to stand up.",
            formTips: "Keep the bar close to your body. Back flat, chest up. Push the floor away.",
            videoURL: "https://www.youtube.com/watch?v=op9kVnSso6Q",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Face Pulls",
            alternateNames: ["Cable Face Pull", "Rope Face Pull", "Rear Delt Pull"],
            primaryMuscleGroups: [.back, .shoulders],
            secondaryMuscleGroups: [.traps],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Pull rope attachment to face level, separating hands at the end.",
            formTips: "Great for posture and shoulder health. Pull to your forehead, not chest.",
            videoURL: "https://www.youtube.com/watch?v=rep-qVOkqgk",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Chin-Ups",
            alternateNames: ["Chinups", "Underhand Pull-Up", "Supinated Pull-Up"],
            primaryMuscleGroups: [.back, .biceps],
            secondaryMuscleGroups: [],
            equipment: .pullUpBar,
            difficulty: .intermediate,
            instructions: "Hang from bar with underhand grip, pull up until chin clears bar.",
            formTips: "Underhand grip emphasizes biceps more than pull-ups. Full range of motion.",
            videoURL: "https://www.youtube.com/watch?v=brhRXlOhsAM",
            movementPattern: .verticalPull
        ),
        Exercise(
            name: "T-Bar Row",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps, .lowerBack],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Straddle bar or use landmine, pull weight to chest.",
            formTips: "Keep back flat, chest up. Classic old-school back builder.",
            videoURL: "https://www.youtube.com/watch?v=j3Igk5nyZE4",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Pendlay Row",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps, .lowerBack],
            equipment: .barbell,
            difficulty: .advanced,
            instructions: "Row from floor with back parallel to ground, return bar to floor each rep.",
            formTips: "Explosive pull, controlled lower. Back stays flat throughout.",
            videoURL: "https://www.youtube.com/watch?v=ZlRrIsoDpKg",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Chest Supported Row",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Lie face down on incline bench, row dumbbells up to sides.",
            formTips: "Eliminates lower back strain. Focus on squeezing shoulder blades.",
            videoURL: "https://www.youtube.com/watch?v=H75im9fAUMc",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Straight Arm Pulldown",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Stand at cable machine, push bar down in arc with straight arms.",
            formTips: "Keep arms straight throughout. Great for lat isolation.",
            videoURL: "https://www.youtube.com/watch?v=AjCCGN2Bc80",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Back Extension",
            primaryMuscleGroups: [.lowerBack],
            secondaryMuscleGroups: [.glutes, .hamstrings],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "On hyperextension bench, lower torso down then raise back up.",
            formTips: "Don't hyperextend at the top. Can hold weight for added resistance.",
            videoURL: "https://www.youtube.com/watch?v=ph3pddpKzzw",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Barbell Shrugs",
            primaryMuscleGroups: [.traps],
            secondaryMuscleGroups: [],
            equipment: .barbell,
            difficulty: .beginner,
            instructions: "Hold barbell at thighs, shrug shoulders straight up toward ears.",
            formTips: "Don't roll shoulders. Straight up and down. Pause at top.",
            videoURL: "https://www.youtube.com/watch?v=cJRVVxmytaM",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dumbbell Shrugs",
            primaryMuscleGroups: [.traps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Hold dumbbells at sides, shrug shoulders up toward ears.",
            formTips: "Allows more natural arm position than barbell. Hold at top.",
            videoURL: "https://www.youtube.com/watch?v=cJRVVxmytaM",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Rack Pulls",
            primaryMuscleGroups: [.back, .traps],
            secondaryMuscleGroups: [.glutes, .hamstrings],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Deadlift from pins set at knee height or above.",
            formTips: "Great for upper back and lockout strength. Go heavy.",
            videoURL: "https://www.youtube.com/watch?v=PfP8A6UFDgI",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Meadows Row",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Stand perpendicular to landmine, row with overhand grip.",
            formTips: "Created by John Meadows. Great for lat stretch and contraction.",
            videoURL: "https://www.youtube.com/watch?v=xQhni67uBqs",
            movementPattern: .horizontalPull,
            isUnilateral: true
        )
    ]

    // MARK: - Shoulder Exercises

    let shoulderExercises: [Exercise] = [
        Exercise(
            name: "Overhead Press",
            alternateNames: ["OHP", "Military Press", "Standing Press", "Strict Press"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Press barbell from shoulder level to overhead.",
            formTips: "Keep core tight, don't lean back excessively. Full lockout at top.",
            videoURL: "https://www.youtube.com/watch?v=2yjwXTZQDDI",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Dumbbell Shoulder Press",
            alternateNames: ["DB Shoulder Press", "Seated Dumbbell Press", "DB Overhead Press"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Press dumbbells from shoulder level to overhead.",
            formTips: "Can be done seated or standing. Don't clang the dumbbells at the top.",
            videoURL: "https://www.youtube.com/watch?v=qEwKCR5JCog",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Lateral Raises",
            alternateNames: ["Side Raises", "Lateral Delt Raise", "Side Lateral Raise", "Dumbbell Lateral Raise"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Raise dumbbells out to sides until arms are parallel to ground.",
            formTips: "Use lighter weight, control the movement. Slight bend in elbows.",
            videoURL: "https://www.youtube.com/watch?v=3VcKaXpzqRo",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Front Raises",
            alternateNames: ["Front Delt Raise", "Dumbbell Front Raise", "Anterior Delt Raise"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Raise dumbbells in front of you to shoulder height.",
            formTips: "Don't swing. Alternate arms or do both together.",
            videoURL: "https://www.youtube.com/watch?v=-t7fuZ0KhDA",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Rear Delt Flyes",
            alternateNames: ["Reverse Fly", "Bent Over Fly", "Rear Delt Raise", "Posterior Delt Fly"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.back],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Bend over, raise dumbbells out to sides targeting rear delts.",
            formTips: "Keep your back flat. Light weight, high reps work well.",
            videoURL: "https://www.youtube.com/watch?v=EA7u4Q_8HQ0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Arnold Press",
            alternateNames: ["Arnold Dumbbell Press", "Rotating Shoulder Press"],
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Start with palms facing you, rotate as you press overhead.",
            formTips: "The rotation targets all three heads of the deltoid.",
            videoURL: "https://www.youtube.com/watch?v=6Z15_WdXmVw",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Seated Military Press",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Sit on bench with back support, press barbell from shoulders to overhead.",
            formTips: "Keep core tight and back against pad. Strict form, no leg drive.",
            videoURL: "https://www.youtube.com/watch?v=2yjwXTZQDDI",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Upright Row",
            primaryMuscleGroups: [.shoulders, .traps],
            secondaryMuscleGroups: [.biceps],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Pull barbell straight up along body to chin level, elbows high.",
            formTips: "Wide grip is easier on shoulders. Don't go too heavy.",
            videoURL: "https://www.youtube.com/watch?v=amCU-ziHITM",
            movementPattern: .verticalPull
        ),
        Exercise(
            name: "Cable Lateral Raise",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Stand beside low cable, raise arm out to side until parallel.",
            formTips: "Constant tension throughout. Great for side delt isolation.",
            videoURL: "https://www.youtube.com/watch?v=PPrzBWGaWf8",
            movementPattern: .isolation,
            isUnilateral: true
        ),
        Exercise(
            name: "Machine Shoulder Press",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .bodyweightOnly,
            specificMachine: .shoulderPress,
            difficulty: .beginner,
            instructions: "Sit at shoulder press machine, press handles overhead.",
            formTips: "Good for beginners. Keeps you in a fixed path.",
            videoURL: "https://www.youtube.com/watch?v=Wqq43dKW1TU",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Reverse Pec Deck",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.back],
            equipment: .bodyweightOnly,
            specificMachine: .reversePecDeck,
            difficulty: .beginner,
            instructions: "Face pec deck machine, pull handles back squeezing rear delts.",
            formTips: "Targets rear delts. Keep arms parallel to floor.",
            videoURL: "https://www.youtube.com/watch?v=5YK4bgzXDp0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Lu Raises",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.traps],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Raise dumbbells in front to overhead in Y pattern with thumbs up.",
            formTips: "Named after Lu Xiaojun. Light weight, full range of motion.",
            videoURL: "https://www.youtube.com/watch?v=HuIPmb_SGes",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Behind the Neck Press",
            primaryMuscleGroups: [.shoulders],
            secondaryMuscleGroups: [.triceps],
            equipment: .barbell,
            difficulty: .advanced,
            instructions: "Press barbell from behind neck to overhead.",
            formTips: "Requires good shoulder mobility. Not for everyone. Go light.",
            videoURL: "https://www.youtube.com/watch?v=WvePgOFmkJM",
            movementPattern: .verticalPush
        )
    ]

    // MARK: - Bicep Exercises

    let bicepExercises: [Exercise] = [
        Exercise(
            name: "Barbell Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [.forearms],
            equipment: .barbell,
            difficulty: .beginner,
            instructions: "Curl barbell from thighs to shoulders, keeping elbows at sides.",
            formTips: "Don't swing or use momentum. Keep elbows pinned to your sides.",
            videoURL: "https://www.youtube.com/watch?v=kwG2ipFRgfo",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dumbbell Curl",
            alternateNames: ["DB Curl", "Bicep Curl", "Standing Dumbbell Curl", "Alternating Dumbbell Curl"],
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [.forearms],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Curl dumbbells alternating or together, elbows at sides.",
            formTips: "Supinate (rotate palm up) as you curl for full bicep activation.",
            videoURL: "https://www.youtube.com/watch?v=ykJmrZ5v0Oo",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Hammer Curls",
            alternateNames: ["Hammer Curl", "Neutral Grip Curl", "DB Hammer Curl"],
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [.forearms],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Curl dumbbells with palms facing each other throughout.",
            formTips: "Targets the brachialis and forearms. Keep wrists neutral.",
            videoURL: "https://www.youtube.com/watch?v=zC3nLlEvin4",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Preacher Curls",
            alternateNames: ["Preacher Curl", "Scott Curl", "Preacher Bench Curl"],
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Rest arms on preacher bench, curl weight up.",
            formTips: "Don't fully extend at the bottom to keep tension on the biceps.",
            videoURL: "https://www.youtube.com/watch?v=fIWP-FRFNU0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Cable Curls",
            alternateNames: ["Cable Bicep Curl", "Low Cable Curl", "Standing Cable Curl"],
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [.forearms],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Stand at low cable, curl handle to shoulders.",
            formTips: "Constant tension throughout the movement. Great for pump.",
            videoURL: "https://www.youtube.com/watch?v=NFzTWp2qpiE",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Incline Dumbbell Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Sit on incline bench, let arms hang, curl dumbbells up.",
            formTips: "The stretch at the bottom increases bicep activation.",
            videoURL: "https://www.youtube.com/watch?v=soxrZlIl35U",
            movementPattern: .isolation
        ),
        Exercise(
            name: "EZ Bar Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [.forearms],
            equipment: .barbell,
            difficulty: .beginner,
            instructions: "Curl EZ bar from thighs to shoulders using angled grip.",
            formTips: "Easier on wrists than straight bar. Keep elbows pinned.",
            videoURL: "https://www.youtube.com/watch?v=zG2xJ0Q5QtI",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Concentration Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Sit with elbow braced on inner thigh, curl dumbbell up.",
            formTips: "Isolates the bicep. Squeeze at the top of each rep.",
            videoURL: "https://www.youtube.com/watch?v=Jvj2wV0vOYU",
            movementPattern: .isolation,
            isUnilateral: true
        ),
        Exercise(
            name: "Spider Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Lie chest-down on incline bench, curl dumbbells up.",
            formTips: "Arms hang straight down. Great peak contraction.",
            videoURL: "https://www.youtube.com/watch?v=ke3JGzLiME4",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Reverse Curl",
            primaryMuscleGroups: [.forearms],
            secondaryMuscleGroups: [.biceps],
            equipment: .barbell,
            difficulty: .beginner,
            instructions: "Curl barbell with overhand (pronated) grip.",
            formTips: "Targets brachioradialis and forearms. Go lighter than regular curls.",
            videoURL: "https://www.youtube.com/watch?v=nRgxYX2Ve9w",
            movementPattern: .isolation
        ),
        Exercise(
            name: "21s",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "7 reps bottom half, 7 reps top half, 7 full reps.",
            formTips: "Classic bicep finisher. Use lighter weight than normal.",
            videoURL: "https://www.youtube.com/watch?v=_d8U0H5hLQA",
            movementPattern: .isolation
        )
    ]

    // MARK: - Tricep Exercises

    let tricepExercises: [Exercise] = [
        Exercise(
            name: "Tricep Pushdown",
            alternateNames: ["Cable Pushdown", "Tricep Pressdown", "Straight Bar Pushdown"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Push cable attachment down until arms are straight.",
            formTips: "Keep elbows at your sides. Squeeze at the bottom.",
            videoURL: "https://www.youtube.com/watch?v=2-LAMcpzODU",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Skull Crushers",
            alternateNames: ["Lying Tricep Extension", "French Press", "Nose Breakers", "EZ Bar Skull Crusher"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Lie on bench, lower bar to forehead, extend back up.",
            formTips: "Keep upper arms vertical. Control the descent.",
            videoURL: "https://www.youtube.com/watch?v=d_KZxkY_0cM",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Overhead Tricep Extension",
            alternateNames: ["DB Overhead Extension", "Tricep Overhead Extension", "French Press"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Hold dumbbell overhead, lower behind head, extend back up.",
            formTips: "Keep elbows pointed forward and close to your head.",
            videoURL: "https://www.youtube.com/watch?v=YbX7Wd8jQ-Q",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dips",
            alternateNames: ["Parallel Bar Dips", "Tricep Dips", "Chest Dips", "Bodyweight Dips"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest, .shoulders],
            equipment: .bodyweightOnly,
            difficulty: .intermediate,
            instructions: "Lower body between parallel bars, push back up.",
            formTips: "Lean forward slightly for chest focus, stay upright for triceps.",
            videoURL: "https://www.youtube.com/watch?v=2z8JmcrW-As",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Close Grip Bench Press",
            alternateNames: ["CGBP", "Close Grip Bench", "Narrow Grip Bench Press"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Bench press with hands shoulder-width or closer.",
            formTips: "Don't go too narrow - shoulder width is fine. Elbows tucked.",
            videoURL: "https://www.youtube.com/watch?v=nEF0bv2FW94",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Tricep Kickbacks",
            alternateNames: ["DB Kickback", "Dumbbell Kickback", "Tricep Kickback"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Bend over, extend arm back until straight.",
            formTips: "Keep upper arm parallel to the ground. Light weight, full extension.",
            videoURL: "https://www.youtube.com/watch?v=ZO81bExngMI",
            movementPattern: .isolation,
            isUnilateral: true
        ),
        Exercise(
            name: "Rope Pushdown",
            alternateNames: ["Tricep Rope Pushdown", "Cable Rope Extension", "Rope Tricep Extension"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Push rope attachment down, spreading ends apart at bottom.",
            formTips: "Spread the rope at the bottom for extra contraction.",
            videoURL: "https://www.youtube.com/watch?v=vB5OHsJ3EME",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Overhead Cable Extension",
            alternateNames: ["Cable Overhead Tricep Extension", "Rope Overhead Extension"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Face away from cable, extend rope overhead.",
            formTips: "Great stretch on the long head. Keep elbows pointed forward.",
            videoURL: "https://www.youtube.com/watch?v=mLUEBTv880w",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dip Machine",
            alternateNames: ["Assisted Dip Machine", "Machine Dip", "Tricep Dip Machine"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            equipment: .bodyweightOnly,
            specificMachine: .dipMachine,
            difficulty: .beginner,
            instructions: "Sit at dip machine, press handles down.",
            formTips: "Good alternative if bodyweight dips are too hard.",
            videoURL: "https://www.youtube.com/watch?v=6MlzgfGWOyE",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Diamond Push-Ups",
            alternateNames: ["Close Grip Push-Up", "Triangle Push-Up"],
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            equipment: .bodyweightOnly,
            difficulty: .intermediate,
            instructions: "Push-up with hands together forming a diamond shape.",
            formTips: "Hands close together under chest. Elbows tucked.",
            videoURL: "https://www.youtube.com/watch?v=J0DnG1_S92I",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "JM Press",
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [],
            equipment: .barbell,
            difficulty: .advanced,
            instructions: "Hybrid between close grip bench and skull crusher.",
            formTips: "Bar comes to chin/neck area. Advanced movement.",
            videoURL: "https://www.youtube.com/watch?v=dTKMDl9VlJU",
            movementPattern: .horizontalPush
        )
    ]

    // MARK: - Leg Exercises

    let legExercises: [Exercise] = [
        Exercise(
            name: "Barbell Squat",
            alternateNames: ["Back Squat", "Squat", "BB Squat", "High Bar Squat", "Low Bar Squat"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings, .lowerBack],
            equipment: .squat,
            difficulty: .intermediate,
            instructions: "Bar on upper back, squat down until thighs are parallel, stand up.",
            formTips: "Knees track over toes, chest up, core tight. Don't let knees cave in.",
            videoURL: "https://www.youtube.com/watch?v=ultWZbUMPL8",
            movementPattern: .squat
        ),
        Exercise(
            name: "Leg Press",
            alternateNames: ["Plate Loaded Leg Press", "45 Degree Leg Press", "Sled Leg Press"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .legPress,
            difficulty: .beginner,
            instructions: "Sit in leg press machine, lower weight, press back up.",
            formTips: "Don't lock out knees completely. Keep lower back pressed into seat.",
            videoURL: "https://www.youtube.com/watch?v=IZxyjW7MPJQ",
            movementPattern: .squat
        ),
        Exercise(
            name: "Cable Leg Press",
            alternateNames: ["Seated Leg Press", "Machine Leg Press", "Horizontal Leg Press"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Sit at cable/selectorized leg press machine, press platform away.",
            formTips: "Great for beginners. Controlled path of motion. Don't lock knees.",
            videoURL: "https://www.youtube.com/watch?v=IZxyjW7MPJQ",
            movementPattern: .squat
        ),
        Exercise(
            name: "Romanian Deadlift",
            alternateNames: ["RDL", "Stiff Leg Deadlift", "SLDL", "Romanian DL"],
            primaryMuscleGroups: [.hamstrings, .glutes],
            secondaryMuscleGroups: [.lowerBack],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Hinge at hips, lower bar down legs, return to standing.",
            formTips: "Keep bar close to legs. Feel the stretch in hamstrings. Soft knee bend.",
            videoURL: "https://www.youtube.com/watch?v=7j-2w4-P14I",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Lunges",
            alternateNames: ["Forward Lunge", "Dumbbell Lunge", "Static Lunge"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Step forward, lower back knee toward ground, push back up.",
            formTips: "Keep torso upright. Front knee doesn't go past toes.",
            videoURL: "https://www.youtube.com/watch?v=QOVaHwm-Q6U",
            movementPattern: .lunge,
            isUnilateral: true
        ),
        Exercise(
            name: "Lying Leg Curl",
            alternateNames: ["Prone Leg Curl", "Leg Curl Machine", "Hamstring Curl"],
            primaryMuscleGroups: [.hamstrings],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Lie face down on machine, curl weight up toward glutes.",
            formTips: "Don't lift hips off the pad. Control the negative.",
            videoURL: "https://www.youtube.com/watch?v=1Tq3QdYUuHs",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Seated Leg Curl",
            alternateNames: ["Sitting Leg Curl", "Seated Hamstring Curl"],
            primaryMuscleGroups: [.hamstrings],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Sit at machine with legs extended, curl heels toward glutes.",
            formTips: "Keep back against pad. Control both phases of movement.",
            videoURL: "https://www.youtube.com/watch?v=Orxowest56U",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Leg Extensions",
            alternateNames: ["Leg Extension Machine", "Quad Extension", "Seated Leg Extension"],
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Sit on machine, extend legs until straight.",
            formTips: "Don't use heavy weight - hard on the knees. Focus on the squeeze.",
            videoURL: "https://www.youtube.com/watch?v=YyvSfVjQeL0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Calf Raises",
            alternateNames: ["Standing Calf Raise", "Calf Raise", "Bodyweight Calf Raise"],
            primaryMuscleGroups: [.calves],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Rise up on toes, lower back down.",
            formTips: "Full range of motion. Pause at the top. Can add weight.",
            videoURL: "https://www.youtube.com/watch?v=gwLzBJYoWlI",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Bulgarian Split Squat",
            alternateNames: ["BSS", "Rear Foot Elevated Split Squat", "RFESS", "Single Leg Squat"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Rear foot elevated on bench, squat down on front leg.",
            formTips: "Torso upright. Great for leg development and balance.",
            videoURL: "https://www.youtube.com/watch?v=2C-uNgKwPLE",
            movementPattern: .lunge,
            isUnilateral: true
        ),
        Exercise(
            name: "Hip Thrust",
            alternateNames: ["Barbell Hip Thrust", "Glute Bridge", "Weighted Hip Thrust"],
            primaryMuscleGroups: [.glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Upper back on bench, thrust hips up with barbell across hips.",
            formTips: "Squeeze glutes hard at the top. Chin tucked, don't hyperextend.",
            videoURL: "https://www.youtube.com/watch?v=SEdqd1n0cvg",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Front Squat",
            alternateNames: ["Barbell Front Squat", "BB Front Squat"],
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [.glutes, .abs],
            equipment: .barbell,
            difficulty: .advanced,
            instructions: "Bar rests on front delts, squat down keeping torso upright.",
            formTips: "Elbows high, core tight. More quad dominant than back squat.",
            videoURL: "https://www.youtube.com/watch?v=m4ytaCJZpl0",
            movementPattern: .squat
        ),
        Exercise(
            name: "Hack Squat",
            alternateNames: ["Hack Squat Machine", "Machine Hack Squat", "Reverse Hack Squat"],
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [.glutes],
            equipment: .bodyweightOnly,
            specificMachine: .hackSquat,
            difficulty: .intermediate,
            instructions: "Stand on hack squat machine, lower body then press up.",
            formTips: "Foot position changes emphasis. Lower is more quads, higher is more glutes.",
            videoURL: "https://www.youtube.com/watch?v=0tn5K9NlCfo",
            movementPattern: .squat
        ),
        Exercise(
            name: "Goblet Squat",
            alternateNames: ["DB Goblet Squat", "Dumbbell Goblet Squat", "Kettlebell Squat"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.abs],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Hold dumbbell at chest, squat down between legs.",
            formTips: "Great for learning squat form. Elbows track inside knees.",
            videoURL: "https://www.youtube.com/watch?v=MeIiIdhvXT4",
            movementPattern: .squat
        ),
        Exercise(
            name: "Pendulum Squat",
            alternateNames: ["Pendulum Squat Machine"],
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [.glutes],
            equipment: .bodyweightOnly,
            specificMachine: .hackSquat,
            difficulty: .intermediate,
            instructions: "Stand on pendulum squat machine, lower body using the arc motion.",
            formTips: "Arc motion keeps constant tension on quads. Excellent for knee-friendly squatting.",
            videoURL: "https://www.youtube.com/watch?v=NqFuU2fYrS8",
            movementPattern: .squat
        ),
        Exercise(
            name: "Smith Machine Squat",
            alternateNames: ["Smith Squat", "Guided Squat"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .smithMachine,
            difficulty: .beginner,
            instructions: "Position bar on upper back, unrack and squat down.",
            formTips: "Fixed path allows different foot positions. Good for beginners or isolation.",
            videoURL: "https://www.youtube.com/watch?v=b0r1LWtAqiU",
            movementPattern: .squat
        ),
        Exercise(
            name: "Seated Calf Raise",
            primaryMuscleGroups: [.calves],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            specificMachine: .seatedCalfRaise,
            difficulty: .beginner,
            instructions: "Sit at calf raise machine, raise heels up.",
            formTips: "Targets the soleus muscle. Full stretch at bottom.",
            videoURL: "https://www.youtube.com/watch?v=JbyjNymZOt0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Standing Calf Raise Machine",
            primaryMuscleGroups: [.calves],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            specificMachine: .standingCalfRaise,
            difficulty: .beginner,
            instructions: "Stand on calf raise machine, raise heels up.",
            formTips: "Targets the gastrocnemius. Pause at top and bottom.",
            videoURL: "https://www.youtube.com/watch?v=RLnJ_6Dqkns",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Glute Kickback Machine",
            primaryMuscleGroups: [.glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .bodyweightOnly,
            specificMachine: .gluteKickback,
            difficulty: .beginner,
            instructions: "Stand at machine, kick leg back against resistance.",
            formTips: "Squeeze glute at the top. Don't use momentum.",
            videoURL: "https://www.youtube.com/watch?v=CPUN9v5IYGQ",
            movementPattern: .isolation,
            isUnilateral: true
        ),
        Exercise(
            name: "Hip Adduction Machine",
            primaryMuscleGroups: [.glutes],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            specificMachine: .hipAdduction,
            difficulty: .beginner,
            instructions: "Sit at machine, squeeze legs together.",
            formTips: "Targets inner thighs. Control the movement both ways.",
            videoURL: "https://www.youtube.com/watch?v=O_DNcaEYJac",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Hip Abduction Machine",
            primaryMuscleGroups: [.glutes],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            specificMachine: .hipAbduction,
            difficulty: .beginner,
            instructions: "Sit at machine, push legs apart.",
            formTips: "Targets outer glutes. Keep back against pad.",
            videoURL: "https://www.youtube.com/watch?v=FNJErCOeFQM",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Good Mornings",
            primaryMuscleGroups: [.hamstrings, .lowerBack],
            secondaryMuscleGroups: [.glutes],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Bar on back, hinge at hips keeping legs nearly straight.",
            formTips: "Keep back flat. Feel stretch in hamstrings. Go light at first.",
            videoURL: "https://www.youtube.com/watch?v=YA-h3n9L4YU",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Sumo Deadlift",
            primaryMuscleGroups: [.glutes, .hamstrings],
            secondaryMuscleGroups: [.quads, .back],
            equipment: .barbell,
            difficulty: .intermediate,
            instructions: "Wide stance, grip inside legs, drive through heels to stand.",
            formTips: "Push knees out, chest up. More glute/adductor emphasis.",
            videoURL: "https://www.youtube.com/watch?v=lDt8HwxVST0",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Walking Lunges",
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .dumbbells,
            difficulty: .intermediate,
            instructions: "Lunge forward, alternate legs as you walk.",
            formTips: "Take big steps. Keep torso upright. Great for conditioning.",
            videoURL: "https://www.youtube.com/watch?v=L8fvypPrzzs",
            movementPattern: .lunge,
            isUnilateral: true
        ),
        Exercise(
            name: "Step-Ups",
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Step up onto bench, drive through front heel.",
            formTips: "Don't push off back foot. All the work from front leg.",
            videoURL: "https://www.youtube.com/watch?v=WCFCdxzFBa4",
            movementPattern: .lunge,
            isUnilateral: true
        ),
        Exercise(
            name: "Sissy Squat",
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .advanced,
            instructions: "Lean back, bend knees, lower body while staying on toes.",
            formTips: "Extreme quad isolation. Hold onto something for balance.",
            videoURL: "https://www.youtube.com/watch?v=ouqyvk0z3Ks",
            movementPattern: .squat
        ),
        Exercise(
            name: "Nordic Hamstring Curl",
            primaryMuscleGroups: [.hamstrings],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .advanced,
            instructions: "Kneel with feet anchored, lower body forward under control.",
            formTips: "Excellent for hamstring strength and injury prevention.",
            videoURL: "https://www.youtube.com/watch?v=2s0f1Kjwpw4",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dumbbell Romanian Deadlift",
            primaryMuscleGroups: [.hamstrings, .glutes],
            secondaryMuscleGroups: [.lowerBack],
            equipment: .dumbbells,
            difficulty: .beginner,
            instructions: "Hinge at hips with dumbbells, lower along legs.",
            formTips: "Same as barbell RDL but allows more freedom of movement.",
            videoURL: "https://www.youtube.com/watch?v=hQgFixeXdZo",
            movementPattern: .hipHinge
        )
    ]

    // MARK: - Core Exercises

    let coreExercises: [Exercise] = [
        Exercise(
            name: "Plank",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.obliques],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Hold push-up position on forearms, body straight.",
            formTips: "Don't let hips sag or pike up. Squeeze glutes and core.",
            videoURL: "https://www.youtube.com/watch?v=ASdvN_XEl_c",
            movementPattern: .isometric,
            supportsTiming: true
        ),
        Exercise(
            name: "Crunches",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Lie on back, curl shoulders off ground toward knees.",
            formTips: "Don't pull on your neck. Focus on the contraction, not range of motion.",
            videoURL: "https://www.youtube.com/watch?v=Xyd_fa5zoEU",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Hanging Leg Raises",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.obliques],
            equipment: .pullUpBar,
            difficulty: .intermediate,
            instructions: "Hang from bar, raise legs until parallel to ground.",
            formTips: "Control the movement, don't swing. Bent knees for easier version.",
            videoURL: "https://www.youtube.com/watch?v=hdng3Nm1x_E",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Russian Twists",
            primaryMuscleGroups: [.obliques],
            secondaryMuscleGroups: [.abs],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Sit with knees bent, lean back, rotate torso side to side.",
            formTips: "Keep feet off ground for added difficulty. Can hold weight.",
            videoURL: "https://www.youtube.com/watch?v=wkD8rjkodUI",
            movementPattern: .rotational
        ),
        Exercise(
            name: "Cable Woodchop",
            primaryMuscleGroups: [.obliques],
            secondaryMuscleGroups: [.abs],
            equipment: .cables,
            difficulty: .intermediate,
            instructions: "Pull cable diagonally across body from high to low or vice versa.",
            formTips: "Rotate through your core, not just your arms. Control the return.",
            videoURL: "https://www.youtube.com/watch?v=pAplQXk3dkU",
            movementPattern: .rotational
        ),
        Exercise(
            name: "Dead Bug",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.lowerBack],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Lie on back, extend opposite arm and leg while keeping back flat.",
            formTips: "Keep lower back pressed into floor. Great for core stability.",
            videoURL: "https://www.youtube.com/watch?v=I5xbsA71v1A",
            movementPattern: .isometric
        ),
        Exercise(
            name: "Ab Wheel Rollout",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.lowerBack],
            equipment: .bodyweightOnly,
            difficulty: .advanced,
            instructions: "Kneel with ab wheel, roll out as far as possible, roll back.",
            formTips: "Keep core tight throughout. Don't let lower back sag.",
            videoURL: "https://www.youtube.com/watch?v=rqiTPdK1c_I",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Decline Sit-Ups",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [],
            equipment: .bench,
            difficulty: .intermediate,
            instructions: "Lie on decline bench, feet hooked, sit up to knees.",
            formTips: "Don't pull on neck. Can hold weight for added resistance.",
            videoURL: "https://www.youtube.com/watch?v=XbaoIL9hHOQ",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Cable Crunch",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Kneel at cable machine, crunch down bringing elbows to knees.",
            formTips: "Focus on flexing the spine, not just hinging at hips.",
            videoURL: "https://www.youtube.com/watch?v=ToJeyhydUxU",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Side Plank",
            primaryMuscleGroups: [.obliques],
            secondaryMuscleGroups: [.abs],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Support body on forearm and feet, hips off ground.",
            formTips: "Keep body in straight line. Don't let hips sag.",
            videoURL: "https://www.youtube.com/watch?v=K2VljzCC16g",
            movementPattern: .isometric,
            supportsTiming: true
        ),
        Exercise(
            name: "Mountain Climbers",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.shoulders],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "In push-up position, alternate driving knees to chest.",
            formTips: "Keep hips down. Great for cardio and core.",
            videoURL: "https://www.youtube.com/watch?v=nmwgirgXLYM",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Bicycle Crunches",
            primaryMuscleGroups: [.abs, .obliques],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Lie on back, alternate elbow to opposite knee.",
            formTips: "Don't pull on neck. Fully extend the straight leg.",
            videoURL: "https://www.youtube.com/watch?v=1we3bh9uhqY",
            movementPattern: .isolation
        ),
        Exercise(
            name: "V-Ups",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .intermediate,
            instructions: "Lie flat, raise legs and torso simultaneously, touch toes.",
            formTips: "Keep legs straight. Controlled movement up and down.",
            videoURL: "https://www.youtube.com/watch?v=iP2fjvG0g3w",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Pallof Press",
            primaryMuscleGroups: [.abs, .obliques],
            secondaryMuscleGroups: [],
            equipment: .cables,
            difficulty: .beginner,
            instructions: "Stand perpendicular to cable, press handle straight out.",
            formTips: "Anti-rotation exercise. Resist the pull of the cable.",
            videoURL: "https://www.youtube.com/watch?v=AH_QZLm_0-s",
            movementPattern: .isometric
        ),
        Exercise(
            name: "Reverse Crunch",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [],
            equipment: .bodyweightOnly,
            difficulty: .beginner,
            instructions: "Lie on back, curl hips off floor bringing knees to chest.",
            formTips: "Focus on lower abs. Don't use momentum.",
            videoURL: "https://www.youtube.com/watch?v=hyv14e2QDq0",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Dragon Flag",
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.lowerBack],
            equipment: .bench,
            difficulty: .advanced,
            instructions: "Lie on bench, grip behind head, raise body keeping it straight.",
            formTips: "Made famous by Bruce Lee. Very advanced exercise.",
            videoURL: "https://www.youtube.com/watch?v=moyFIvRrS0s",
            movementPattern: .isolation
        )
    ]

    // MARK: - Trap Bar Exercises

    let trapBarExercises: [Exercise] = [
        Exercise(
            name: "Trap Bar Deadlift",
            alternateNames: ["Hex Bar Deadlift", "Trap Bar DL", "Hex Bar DL"],
            primaryMuscleGroups: [.back, .hamstrings, .glutes],
            secondaryMuscleGroups: [.quads, .lowerBack, .traps, .forearms],
            equipment: .trapBar,
            difficulty: .intermediate,
            instructions: "Stand inside the trap bar with feet hip-width apart. Grip the handles, brace your core, and drive through your heels to stand up straight. Lower with control.",
            formTips: "Keep your back flat and chest up throughout. The neutral grip is easier on the lower back than conventional deadlifts. Push the floor away rather than pulling the bar up.",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Trap Bar Shrugs",
            alternateNames: ["Hex Bar Shrugs", "Trap Bar Shoulder Shrugs"],
            primaryMuscleGroups: [.traps],
            secondaryMuscleGroups: [.forearms],
            equipment: .trapBar,
            difficulty: .beginner,
            instructions: "Stand inside the trap bar holding the handles. Keeping arms straight, shrug your shoulders up toward your ears. Hold briefly at the top, then lower with control.",
            formTips: "The neutral grip is easier on your shoulders than barbell shrugs. Don't roll your shoulders - straight up and down only. Hold at the top for maximum contraction.",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Trap Bar Romanian Deadlift",
            alternateNames: ["Hex Bar RDL", "Trap Bar RDL", "Hex Bar Romanian Deadlift"],
            primaryMuscleGroups: [.hamstrings, .glutes],
            secondaryMuscleGroups: [.lowerBack, .back],
            equipment: .trapBar,
            difficulty: .intermediate,
            instructions: "Stand inside the trap bar, lift it to standing position. Push your hips back while keeping a slight bend in your knees, lowering the bar along your legs. Return by driving hips forward.",
            formTips: "Keep a slight knee bend throughout - this is not a stiff-leg deadlift. Feel the stretch in your hamstrings. Keep your back flat and core braced.",
            movementPattern: .hipHinge
        ),
        Exercise(
            name: "Trap Bar Farmer's Walk",
            alternateNames: ["Hex Bar Carry", "Trap Bar Carry", "Loaded Carry"],
            primaryMuscleGroups: [.traps, .forearms],
            secondaryMuscleGroups: [.abs, .glutes, .back],
            equipment: .trapBar,
            difficulty: .beginner,
            instructions: "Stand inside the trap bar and deadlift it up. Walk forward with controlled steps for the prescribed distance or time. Keep your core tight and shoulders back.",
            formTips: "Walk in a controlled manner - don't rush. Keep your core tight and maintain good posture. The trap bar allows heavier loads than dumbbells for carries.",
            movementPattern: .carry
        ),
        Exercise(
            name: "Trap Bar Jump Squats",
            alternateNames: ["Hex Bar Jumps", "Trap Bar Jumps", "Loaded Jumps"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.calves, .hamstrings],
            equipment: .trapBar,
            difficulty: .advanced,
            instructions: "Stand inside the trap bar with light weight. Lower into a quarter squat, then explosively jump upward. Land softly and absorb the impact through your legs before the next rep.",
            formTips: "Use lighter weight than your deadlift - this is for power, not strength. Land softly with bent knees. Great for developing explosive power for sports.",
            movementPattern: .squat
        ),
        Exercise(
            name: "Trap Bar Bent Over Row",
            alternateNames: ["Hex Bar Row", "Trap Bar Row"],
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps, .lowerBack, .forearms],
            equipment: .trapBar,
            difficulty: .intermediate,
            instructions: "Stand inside the trap bar and lift it. Hinge at your hips until your torso is nearly parallel to the ground. Row the bar up to your torso, squeezing your shoulder blades together.",
            formTips: "Keep your back flat throughout the movement. The neutral grip reduces bicep involvement and is easier on the shoulders. Pull with your elbows, not your hands.",
            movementPattern: .horizontalPull
        ),
        Exercise(
            name: "Trap Bar Floor Press",
            alternateNames: ["Hex Bar Floor Press", "Trap Bar Chest Press"],
            primaryMuscleGroups: [.chest, .triceps],
            secondaryMuscleGroups: [.shoulders],
            equipment: .trapBar,
            difficulty: .intermediate,
            instructions: "Lie on the floor inside the trap bar. Grip the handles and press the bar straight up. Lower until your triceps touch the floor, pause briefly, then press back up.",
            formTips: "The neutral grip is easier on your shoulders than a barbell. The floor limits range of motion which can help those with shoulder issues. Control the descent.",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Trap Bar Split Squat",
            alternateNames: ["Hex Bar Bulgarian Split Squat", "Trap Bar Lunge"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings],
            equipment: .trapBar,
            difficulty: .intermediate,
            instructions: "Stand inside the trap bar in a split stance. Lower your back knee toward the ground while keeping your front knee over your ankle. Drive through your front foot to return to standing.",
            formTips: "The trap bar keeps weight centered making balance easier than with dumbbells. Keep your torso upright. Don't let your front knee cave inward.",
            movementPattern: .lunge,
            isUnilateral: true
        )
    ]

    // MARK: - Medicine Ball Exercises

    let medicineBallExercises: [Exercise] = [
        Exercise(
            name: "Medicine Ball Slam",
            alternateNames: ["Ball Slam", "Med Ball Slam", "Overhead Slam"],
            primaryMuscleGroups: [.abs, .shoulders],
            secondaryMuscleGroups: [.back, .obliques],
            equipment: .medicineBall,
            difficulty: .beginner,
            instructions: "Hold medicine ball overhead with arms extended. Explosively throw the ball down to the ground, bending at the hips. Catch the ball on the bounce and repeat.",
            formTips: "Use your whole body - this is not just an arm movement. Engage your core throughout. Let the ball bounce back up naturally. Great for power development and stress relief.",
            movementPattern: .verticalPush,
            supportsTiming: true
        ),
        Exercise(
            name: "Medicine Ball Chest Slam",
            alternateNames: ["Chest Slam", "Med Ball Chest Slam", "Front Slam"],
            primaryMuscleGroups: [.chest, .abs],
            secondaryMuscleGroups: [.shoulders, .obliques],
            equipment: .medicineBall,
            difficulty: .beginner,
            instructions: "Hold medicine ball at chest level with arms bent. Explosively slam the ball down to the ground in front of you, extending through your chest and core. Catch the ball on the bounce and return to chest position.",
            formTips: "Drive through your chest and abs as you slam. Keep your core engaged throughout. This variation emphasizes chest and upper body power more than the overhead version. Great for building explosive pressing strength.",
            movementPattern: .horizontalPush,
            supportsTiming: true
        ),
        Exercise(
            name: "Medicine Ball Chest Pass",
            alternateNames: ["Ball Chest Throw", "Med Ball Pass", "Chest Push"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.shoulders, .triceps],
            equipment: .medicineBall,
            difficulty: .beginner,
            instructions: "Hold ball at chest level. Explosively push the ball forward against a wall or to a partner. Catch the ball as it returns and immediately go into the next rep.",
            formTips: "Keep your core tight and feet planted. Extend through your chest and arms. This develops explosive pushing power for sports.",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Medicine Ball Russian Twist",
            alternateNames: ["Russian Twist with Ball", "Seated Med Ball Twist", "Oblique Twist"],
            primaryMuscleGroups: [.abs, .obliques],
            secondaryMuscleGroups: [],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Sit on floor with knees bent, holding medicine ball at chest. Lean back slightly to engage core. Rotate torso side to side, touching ball to ground on each side.",
            formTips: "Keep your core engaged throughout. The weight of the ball increases the challenge. For extra difficulty, lift your feet off the ground. Control the rotation - don't just swing the ball.",
            movementPattern: .rotational
        ),
        Exercise(
            name: "Medicine Ball Wall Ball",
            alternateNames: ["Wall Ball", "Ball Toss", "Squat and Throw"],
            primaryMuscleGroups: [.quads, .glutes, .shoulders],
            secondaryMuscleGroups: [.abs, .back],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Stand facing wall holding ball at chest. Squat down, then explosively stand while throwing ball up the wall to a target. Catch the ball and immediately go into next rep.",
            formTips: "Use your legs to generate power, not just your arms. Aim for a consistent target height. This is a full-body cardio and strength exercise. Keep your chest up throughout.",
            movementPattern: .squat
        ),
        Exercise(
            name: "Medicine Ball Overhead Throw",
            alternateNames: ["Overhead Ball Throw", "Soccer Throw", "Scoop Toss"],
            primaryMuscleGroups: [.shoulders, .back],
            secondaryMuscleGroups: [.abs, .triceps],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Hold ball overhead with both hands. Explosively throw the ball forward and down against a wall or to a partner. Follow through with your core and hips.",
            formTips: "Generate power from your core and hips, not just your arms. Step forward as you throw for more power. Great for developing throwing power for sports.",
            movementPattern: .verticalPush
        ),
        Exercise(
            name: "Medicine Ball Rotational Throw",
            alternateNames: ["Side Throw", "Rotational Toss", "Woodchop Throw"],
            primaryMuscleGroups: [.obliques, .abs],
            secondaryMuscleGroups: [.shoulders, .back],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Stand sideways to a wall. Hold ball at hip level on the side away from wall. Rotate explosively, throwing ball against wall. Catch and repeat, then switch sides.",
            formTips: "Rotate from your core, not just your arms. Let your hips and feet pivot naturally. Excellent for rotational power development. Keep your core tight throughout.",
            movementPattern: .rotational,
            isUnilateral: true
        ),
        Exercise(
            name: "Medicine Ball Push-Up",
            alternateNames: ["Ball Push-Up", "Unstable Push-Up", "Med Ball Press-Up"],
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders, .abs],
            equipment: .medicineBall,
            difficulty: .advanced,
            instructions: "Place one or both hands on medicine ball in push-up position. Perform push-ups while maintaining balance on the ball. For easier variation, use just one hand on the ball.",
            formTips: "The instability engages more core and stabilizer muscles. Keep your body in a straight line. For single-ball variation, alternate which hand is on the ball between sets.",
            movementPattern: .horizontalPush
        ),
        Exercise(
            name: "Medicine Ball Squat",
            alternateNames: ["Goblet Squat with Ball", "Ball Squat", "Med Ball Front Squat"],
            primaryMuscleGroups: [.quads, .glutes],
            secondaryMuscleGroups: [.hamstrings, .abs],
            equipment: .medicineBall,
            difficulty: .beginner,
            instructions: "Hold medicine ball at chest level. Squat down keeping chest up and knees tracking over toes. Drive through heels to stand back up.",
            formTips: "Keep the ball close to your chest throughout. The weight helps counterbalance and teaches proper squat form. Great beginner variation before advancing to barbell squats.",
            movementPattern: .squat
        ),
        Exercise(
            name: "Medicine Ball Lunge with Twist",
            alternateNames: ["Rotational Lunge", "Lunge and Twist", "Med Ball Lunge Rotation"],
            primaryMuscleGroups: [.quads, .glutes, .obliques],
            secondaryMuscleGroups: [.hamstrings, .abs],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Hold ball at chest. Step forward into a lunge. While in the lunge position, rotate your torso toward the front leg. Return to center, step back, and repeat on other side.",
            formTips: "Keep your front knee over your ankle. The rotation engages your obliques and challenges your balance. Don't let your knee cave inward. This combines lower body strength with core rotation.",
            movementPattern: .lunge,
            isUnilateral: true
        ),
        Exercise(
            name: "Medicine Ball V-Up",
            alternateNames: ["Ball V-Up", "Med Ball Crunch", "Seated Ball Pass"],
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.obliques],
            equipment: .medicineBall,
            difficulty: .advanced,
            instructions: "Lie on back holding medicine ball overhead. Simultaneously lift legs and upper body, passing ball from hands to feet at the top. Lower back down with ball between feet. Repeat, passing ball back to hands.",
            formTips: "Keep your core engaged throughout - don't let your lower back arch off the ground when lowering. The ball transfer makes this significantly harder than standard V-ups. Control the movement.",
            movementPattern: .isolation
        ),
        Exercise(
            name: "Medicine Ball Woodchop",
            alternateNames: ["Diagonal Chop", "Med Ball Chop", "Standing Woodchop"],
            primaryMuscleGroups: [.obliques, .abs],
            secondaryMuscleGroups: [.shoulders],
            equipment: .medicineBall,
            difficulty: .intermediate,
            instructions: "Hold ball with both hands. Start with ball at one shoulder. Rotate and chop down diagonally across your body toward opposite hip, squatting slightly. Return with control and repeat. Switch sides after reps.",
            formTips: "Rotate from your core and hips, not just your arms. Let your feet pivot naturally. This movement pattern mimics chopping wood and builds functional rotational strength.",
            movementPattern: .rotational,
            isUnilateral: true
        ),
        Exercise(
            name: "Medicine Ball Plank Roll",
            alternateNames: ["Ball Roll Plank", "Plank with Ball Roll", "Med Ball Stability Roll"],
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.shoulders, .chest],
            equipment: .medicineBall,
            difficulty: .advanced,
            instructions: "Start in plank position with one hand on medicine ball. Roll the ball to your other hand while maintaining plank position. Continue rolling ball side to side.",
            formTips: "Keep your core tight and hips level - don't let them rotate. The instability makes this extremely challenging. Move slowly and with control. Great for core stability and anti-rotation strength.",
            movementPattern: .isometric,
            supportsTiming: true
        )
    ]

    // MARK: - Search and Filter

    /// Search exercises by name or alternate names
    func search(query: String) -> [Exercise] {
        guard !query.isEmpty else { return exercises }
        let lowercasedQuery = query.lowercased()
        return exercises.filter { exercise in
            // Search primary name
            if exercise.name.lowercased().contains(lowercasedQuery) {
                return true
            }
            // Search alternate names
            return exercise.alternateNames.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Filter exercises by muscle group
    func filterByMuscleGroup(_ muscleGroup: MuscleGroup) -> [Exercise] {
        return exercises.filter {
            $0.primaryMuscleGroups.contains(muscleGroup) ||
            $0.secondaryMuscleGroups.contains(muscleGroup)
        }
    }

    /// Filter exercises by equipment
    func filterByEquipment(_ equipment: Equipment) -> [Exercise] {
        return exercises.filter { $0.equipment == equipment }
    }

    /// Filter exercises by difficulty
    func filterByDifficulty(_ difficulty: ExerciseDifficulty) -> [Exercise] {
        return exercises.filter { $0.difficulty == difficulty }
    }

    /// Filter exercises by available equipment
    func filterByAvailableEquipment(_ availableEquipment: Set<Equipment>) -> [Exercise] {
        return exercises.filter { availableEquipment.contains($0.equipment) }
    }

    /// Get exercises for specific muscle groups with available equipment
    func getExercises(
        for muscleGroups: Set<MuscleGroup>,
        availableEquipment: Set<Equipment>,
        difficulty: ExerciseDifficulty? = nil
    ) -> [Exercise] {
        return exercises.filter { exercise in
            let muscleMatch = !muscleGroups.isDisjoint(with: exercise.primaryMuscleGroups)
            let equipmentMatch = availableEquipment.contains(exercise.equipment)
            let difficultyMatch = difficulty == nil || exercise.difficulty == difficulty
            return muscleMatch && equipmentMatch && difficultyMatch
        }
    }
}
