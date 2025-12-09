# Changelog

All notable changes to IronPath will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-09 (Beta 1)

### Added
- AI-powered workout generation using Claude (configurable model: Haiku/Sonnet/Opus)
- Exercise library with 100+ exercises across all muscle groups
- Alternate names for exercises to improve search (e.g., "RDL" finds "Romanian Deadlift")
- New exercise variations: Cable Leg Press, Lying Leg Curl, Seated Leg Curl, Pendulum Squat, Smith Machine Squat
- Workout history tracking with iCloud sync
- Personal records (PR) detection for weight and volume
- Rest timer with notifications (continues when app is minimized)
- Plate calculator for barbell exercises
- Cable weight calculator with pin location display
- Quick swap suggestions when replacing exercises
- Gym profile management with equipment configuration
- HealthKit integration for workout logging
- API debug mode for troubleshooting
- Persist generated workouts across app restarts
- Persist active workouts across app restarts (resume where you left off)

### Fixed
- iCloud sync now properly restores workout history after app reinstall
- Rest timer continues accurately when app is backgrounded
- Set weight/reps changes now propagate from any set to subsequent sets (not just set 1)

### Technical
- CloudKit integration for workout and gym settings sync
- NSUbiquitousKeyValueStore for user profile and API key sync
- Agentic AI workflow with tool use for intelligent workout generation
