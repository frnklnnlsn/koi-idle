# Koi Idle

A koi pond idle game built in Godot 4, currently in active development. The core focus of the project is a procedural fish simulation system — each fish is individually generated, animated, and simulated with its own stats, appearance, and behavior.

## Highlights

- **Procedural fish animation** — fish bodies are simulated as inverse-kinematics chains with a travelling sine wave overlay, producing fluid, organic movement without any pre-made animations
- **Component-based fish architecture** — the fish system is split into focused, decoupled components: `FishStateMachine`, `FishSteering`, `FishBodyChain`, `FishEating`, and `FishSkeleton`
- **Behavioral state machine** — fish autonomously transition between `VERY_SLOW_SWIM`, `SLOW_SWIM`, `FAST_SWIM`, `ACCELERATING`, `DECELERATING`, and `EATING` states, with eased speed transitions and per-state wave parameters
- **Boundary-aware steering** — fish navigate within configurable pond shapes (circle, ellipse, rectangle) using wander forces, boundary avoidance, and FastNoiseLite micro-jitter
- **Procedural generation** — each fish is generated with a unique ID, color palette (Perlin noise-based pattern), fin color, and stats drawn from a right-skewed bell curve distribution per rank tier
- **Idle economy** — fish have `value`, `income`, `mass`, and logistic growth curves (S-curve carrying capacity) that feed into a passive income system
- **Save system** — persistent save/load via `SaveManager` singleton
- **In-editor Kanban board** — project tasks tracked directly inside Godot using the `kanban_tasks` addon

## System Overview
```
scripts/Singletons/
├── FishGenerator.gd       # Procedural fish stat + visual generation
├── FishHandler.gd         # Manages the active fish collection
├── FishGrowthManager.gd   # Logistic growth curves over time
├── PassiveSystems.gd      # Idle income tick
├── SaveManager.gd         # Persistence
└── DisplayManager.gd      # UI state

game_parts/FishComposition/
├── procedural_fish_2.gd   # Root coordinator — wires all components
├── fish_state_machine.gd  # State transitions + wave param storage
├── fish_steering.gd       # Wander, boundary avoidance, entry override
├── fish_body_chain.gd     # IK chain follow + travelling wave
├── fish_eating.gd         # Two-phase eating behaviour
└── skeleton.gd            # Fin rendering + state-driven ellipse sizing

scripts/
├── fish_conf.gd           # Resource class — fish data schema
├── swim_area.gd           # Pond boundary shapes
└── RarityGraphTheme.gd    # Rarity distribution visualisation
```

## Tech

- **Godot 4** / GDScript
- **GDShader** — water / visual effects
- Logistic growth model (S-curve) for fish maturation
- Right-skewed bell curve stat distribution per rank tier
- FastNoiseLite for steering micro-variation
- Component pattern for fish simulation

## Status

Active development. The fish simulation and generation systems are functional. Idle economy, shop, and UI are in progress.

## Running the Project

Open `koi-idle-godot/` as a Godot 4 project. No external dependencies required.
