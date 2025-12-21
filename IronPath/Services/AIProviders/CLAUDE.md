# AIProviders/

## Files

| File | What | When to read |
| ---- | ---- | ------------ |
| `AIProviderManager.swift` | AI provider selection/configuration | Switching AI providers, API config |
| `AIProvider.swift` | Protocol for AI providers | Adding new AI provider |
| `AnthropicProvider.swift` | Claude API integration | Claude-specific issues |
| `OpenAIProvider.swift` | OpenAI API integration | OpenAI-specific issues |
| `AIModels.swift` | AI request/response models | Modifying AI data structures |
| `AITools.swift` | Tool definitions for AI | Adding AI tool capabilities |
| `AIToolParser.swift` | Parse AI tool calls | Tool call parsing issues |
| `AIProviderHelpers.swift` | Shared AI utilities | Common AI functionality |
| `PromptComponents.swift` | Reusable prompt blocks with priority system | Creating prompt sections, understanding prompt structure |
| `WorkoutSchema.swift` | JSON schema definitions for structured output | Modifying AI response format, adding workout fields |
| `WorkoutPromptBuilder.swift` | Modular prompt builder for workout generation | Assembling prompts, tuning generation parameters |
| `AgentModels.swift` | Agent-based generation models | Agent workflow data |
| `AgentToolExecutor.swift` | Execute agent tool calls | Agent tool implementation |
| `AgentWorkoutBuilder.swift` | Build workouts from agent output | Workout generation from AI |
| `WorkoutAgentTools.swift` | Workout-specific agent tools | AI workout tools |
