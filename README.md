# TJT Game Project

This is a Godot-based tower defense / auto-battler game project. It features units placed on a grid-based arena with strategic combat mechanics, resource management, and shop systems.

## Description

The game is built using Godot Engine 4.5 and utilizes a tile-based system for gameplay. Key features include:

- **Arena System**: The main gameplay area is an arena with a tilemap, divided into play areas where units can be placed.
- **Unit Management**: Units are represented as draggable entities with stats, health/mana bars, and visual skins. Units can be moved between grids using drag-and-drop functionality.
- **Combat System**: Auto-battler with AI pathfinding, automatic targeting, melee/ranged attacks, and abilities.
- **Resource Management**: 
  - **Health & Mana**: Float-based system for precise regeneration during battle
  - **Gold Economy**: Unit purchasing, selling, and combining system
- **Battle Phases**: Preparation phase for unit placement, battle phase with combat, and end phase
- **Shop System**: Unit cards that can be purchased, refreshed, and combined to upgrade tiers
- **Grid-Based Movement**: Units are placed on a grid system, with components handling tile occupation, movement validation, and pathfinding.
- **Interactive Elements**: Includes highlighting, rotation based on velocity during dragging, and outline effects for user feedback.
- **Input Handling**: Supports mouse-based selection and dragging, with cancel options via right-click or escape.

The project includes custom components for various functionalities like drag-and-drop, unit grids, play areas, highlighters, AI pathfinding, and combat systems.

## Project Structure

- **scenes/**: Contains scene files.
  - **arena/**: Main arena scene with tilemap and gameplay logic.
  - **unit/**: Unit scene template with stats, visuals, combat behaviors, and regeneration.
  - **unit_card/**: Shop unit cards for purchasing units.
  - **shop/**: Shop interface for buying and refreshing units.
  - **gold_display/**: UI for displaying player gold.
  - **sell_portal/**: Area where units can be sold for gold.
- **components/**: Reusable GDScript components.
  - `drag_and_drop.gd`: Handles dragging units around the screen.
  - `unit_grid.gd`: Manages a grid of units, tracks occupation.
  - `unit_mover.gd`: Facilitates moving units between play areas.
  - `unit_spawner.gd`: Spawns units into the game world.
  - `play_area.gd`: Represents playable areas on the tilemap.
  - `outline_highlighter.gd`: Adds highlight effects to units.
  - `tile_highlighter.gd`: Highlights tiles.
  - `velocity_based_rotation.gd`: Rotates units based on movement velocity.
  - `unit_ai.gd`: AI system for pathfinding, targeting, and combat behavior.
- **data/**: Game data resources.
  - **units/**: Unit statistics and definitions (.tres files) with stats like health, mana, attack, armor, abilities.
  - **player/**: Player data and state.
- **asset/**: Game assets including sprites, tilesets, fonts, music, sound effects, and shaders.
  - Pixel art assets from 32rogues pack.
  - Tilemaps and autotiles.
  - Audio files for music and SFX.
- **addons/**: Godot plugins for development.
  - **codebot/**: AI-assisted coding plugin for the editor.
  - **sprite_frames_generator/**: Tool for generating sprite frames.
- **reference/**: Additional reference files and possibly older versions.

## Requirements

- Godot Engine (version 4.5.0 or later)
- GL Compatibility rendering mode (configured in project settings)

## How to Run

1. Clone or download the repository.
2. Open Godot Engine.
3. Import the project by selecting the `project.godot` file in the root directory.
4. Run the project from within Godot. The main scene is set to the arena.

## Configuration

- **Window Size**: Viewport 640x360, window override 1300x750.
- **Stretch Mode**: Viewport with integer scaling.
- **Rendering**: GL Compatibility, with pixel-perfect 2D snapping.
- **Inputs**:
  - "select": Left mouse button.
  - "cancel_drag": Right mouse button or Escape key.

## Core Systems

### Battle System
- **BattleManager**: Controls game phases (Preparation → Battle → End)
- **Unit AI**: A* pathfinding with obstacle avoidance
- **Combat**: Automatic targeting, attack cooldowns, damage calculation with armor/magic resist
- **Abilities**: Mana-based special abilities

### Regeneration System
- **Health Regen**: Float-based HP regeneration during battle (configurable per unit)
- **Mana Regen**: Float-based mana regeneration during battle (configurable per unit)
- Both systems use delta-time for smooth, frame-independent regeneration
- Only active during BATTLE phase

### Economy System
- **Gold**: Currency for purchasing units
- **Shop**: Refreshable unit pool with tier-based pricing
- **Combining**: 3 identical units → 1 higher tier unit
- **Selling**: Sell portal returns gold based on unit tier

### Unit Stats
Each unit has the following stats (configured in .tres files):
- `max_health` & `health_regen`: Hit points and regeneration rate
- `max_mana`, `starting_mana`, & `mana_regen`: Resource for abilities
- `attack_damage`, `ability_power`: Damage scaling
- `attack_speed`: Attacks per second
- `armor`, `magic_resist`: Damage reduction
- `attack_range`, `aggro_range`: Combat ranges

## Recent Updates

### Latest Session (November 30, 2025)
- ✅ Fixed console spam from pathfinding debug prints
- ✅ Fixed console spam from mana regeneration system
- ✅ Implemented float-based mana regeneration (fixed int truncation issue)
- ✅ Added health regeneration system during battle
- ✅ Removed health bar white flash effect on HP changes
- ✅ All regeneration systems now use float precision for smooth progression

### Known Issues
- None currently

## Assets

Assets are located in the `asset/` folder and include:

- **Sprites**: Character sprites, items, monsters, tiles from 32rogues asset pack.
- **Tilesets**: Autotiles, animated tiles, and tilemaps (e.g., water tiles).
- **Fonts**: m5x7.ttf for UI.
- **Audio**: Music and sound effects in respective folders.
- **Shaders**: Custom shaders for visual effects.
- **Themes**: UI themes.

## Plugins

The project uses two editor plugins:

- **CodeBot**: Provides AI assistance directly in the Godot editor for coding suggestions and help.
- **SpriteFrames Generator**: A tool to generate sprite frames from images.

## License

See LICENSE file for details.