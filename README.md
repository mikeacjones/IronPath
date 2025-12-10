# IronPath

An AI-powered iOS workout generation app that creates personalized strength training workouts using Claude.

## Features

### AI-Powered Workout Generation
- **Intelligent workout creation** using Claude AI with agentic tool use
- Workouts tailored to your fitness level, goals, and available equipment
- **Progressive overload tracking** - Claude suggests weights based on your history
- **Deload detection** - AI can recommend recovery workouts when needed
- Configurable Claude model (Haiku for speed, Sonnet for balance, Opus for quality)

### Gym Profile Management
- Create multiple gym profiles (home gym, commercial gym, hotel, etc.)
- Configure available equipment per gym
- **Cable machine weight calculator** with pin location display
- **Plate calculator** for barbell exercises
- Custom dumbbell ranges and weight increments

### Workout Tracking
- **Real-time workout logging** with set-by-set tracking
- **Advanced training techniques** - drop sets, rest-pause, and warmup sets
- **Supersets & circuits** - group exercises with automatic navigation and shared rest times
- **Smart superset flow** - warmup sets complete before superset rotation begins
- Rest timer with circular progress indicator and background notifications
- Exercise replacement (AI-powered or quick swap from library)
- Add/remove exercises and sets mid-workout
- **Personal records (PR) detection** for weight and volume
- Workout state persists even if you switch tabs or leave the app

### Exercise Library
- 100+ exercises across all muscle groups
- Search by name, muscle group, or equipment
- Alternate names support (e.g., "RDL" finds "Romanian Deadlift")
- Video links for form reference
- Custom exercise creation via AI

### Progress Tracking
- Workout history with calendar view
- Volume tracking over time
- Personal records board
- Exercise-specific progress charts
- Export to JSON or CSV

### Sync & Integration
- **iCloud sync** across all your devices (workouts, gym profiles, exercise preferences)
- **HealthKit integration** for Apple Health workout logging
- Workouts and settings persist across app restarts and reinstalls

## Requirements

- iOS 17.0+
- Anthropic API key (get one at [console.anthropic.com](https://console.anthropic.com)) or OpenAI API key

## Getting Started

1. Clone the repository
2. Open `IronPath.xcodeproj` in Xcode
3. Build and run on your device or simulator
4. Complete the onboarding flow
5. Add your Anthropic API key in Profile > AI Configuration
6. Generate your first workout!

## Architecture

The app follows an **MVVM architecture** with clear separation of concerns:

```
IronPath/
├── Models/           # Data models (Workout, Exercise, UserProfile, etc.)
├── Views/            # SwiftUI views organized by feature
│   ├── Workout/      # Workout generation and display
│   ├── ActiveWorkout/# In-progress workout tracking
│   ├── History/      # Workout history and calendar
│   ├── Progress/     # Analytics and PR tracking
│   ├── Profile/      # Settings and gym configuration
│   └── Components/   # Shared UI components
├── Services/         # Business logic and API integration
│   ├── AnthropicService    # Claude API integration
│   ├── WorkoutDataManager  # Workout persistence
│   ├── CloudSyncManager    # iCloud synchronization
│   └── HealthKitManager    # Apple Health integration
├── Protocols/        # Protocol definitions for testability
└── Utilities/        # Helper classes and managers
```

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for state management
- **CloudKit** - iCloud data synchronization
- **HealthKit** - Apple Health integration
- **Anthropic Claude API** - AI workout generation with tool use
- **OpenAI API** - Alternative AI provider support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is proprietary software. All rights reserved.

---

## Roadmap

### Workout Experience
| Feature | Description | Status |
|---------|-------------|--------|
| Workout Templates | Save and reuse favorite workouts without AI generation | Planned |
| Superset/Circuit Support | Group exercises together with shared rest times | ✅ Implemented |
| Drop Sets / Rest-Pause / Warm-up Sets | Support for advanced training techniques | ✅ Implemented |
| Smart Superset Navigation | Automatic exercise rotation with warmup set handling | ✅ Implemented |
| Required Technique Enforcement | AI generates workouts with mandatory advanced techniques | ✅ Implemented |
| RPE/RIR Tracking | Rate of Perceived Exertion or Reps in Reserve logging | Planned |

### Social & Sharing
| Feature | Description | Status |
|---------|-------------|--------|
| Workout Sharing | Share workouts with friends via link or QR code | Planned |
| Community Workouts | Browse and try workouts created by others | Planned |
| Progress Photos | Track visual progress alongside workout data | Planned |

### Analytics & Insights
| Feature | Description | Status |
|---------|-------------|--------|
| Muscle Heatmap | Visual representation of trained muscles over time | Planned |
| Fatigue Management | Track accumulated fatigue and suggest deloads | Planned |
| Strength Standards | Compare lifts to population benchmarks | Planned |
| AI Progress Analysis | Claude-powered insights on your training | Planned |

### Planning & Scheduling
| Feature | Description | Status |
|---------|-------------|--------|
| Workout Calendar | Schedule workouts in advance | Planned |
| Program Builder | Create multi-week training programs | Planned |
| Auto-Scheduling | AI suggests optimal workout days based on recovery | Planned |

### Equipment & Exercises
| Feature | Description | Status |
|---------|-------------|--------|
| Barbell Tracking | Track which barbell type used (standard, Olympic, etc.) | Planned |
| 1RM Calculator | Estimate one-rep max from submaximal sets | Planned |
| Exercise Tutorials | In-app video demonstrations | Planned |
| Custom Exercise Builder | Create exercises with your own videos/images | Planned |

### Integration
| Feature | Description | Status |
|---------|-------------|--------|
| Apple Watch App | Log workouts from your wrist | Planned |
| Shortcuts Integration | Automate workout generation | Planned |
| Widget Support | Quick workout stats on home screen | Planned |
| Strava/Garmin Sync | Export to other fitness platforms | Planned |

### Accessibility & UX
| Feature | Description | Status |
|---------|-------------|--------|
| Voice Control | Log sets hands-free | Planned |
| Offline Mode | Generate workouts without internet (cached exercises) | Planned |
| Dark Mode Optimization | OLED-friendly true black theme | Planned |
| Haptic Feedback | Tactile feedback for rest timer and set completion | Planned |
