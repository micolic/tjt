# TODO List - TJT Game Development

## 🔥 High Priority

### Ability System ✅ COMPLETED
- [x] Implement ability casting mechanism when mana is full
- [x] Create base Ability class/resource
- [x] Create Passive Ability system (stat bonuses)
- [x] Visual effects for ability activation (projectile system)
- [x] Cooldown system for abilities
- [x] Create sample abilities (fireball, heal, AOE damage)
- [x] Ability targeting system (self, enemy, area)
- [x] Ability range system
- [x] Mana consumption on ability use
- **Implemented:**
  - Base `Ability` resource class with targeting, cooldown, range
  - `PassiveAbility` for permanent stat bonuses
  - Fireball (single target, 100 dmg, 200 range, projectile visual)
  - Heal (self heal, 30 HP)
  - AOE Damage (all enemies, 25 dmg)
  - Warrior's Endurance passive (+20% health regen for Bjorn)
  - Projectile scene with smooth movement and hit detection

### Wave System
- [ ] Enemy wave spawner component
- [ ] Wave configuration (number of enemies, types, spawn positions)
- [ ] Progressive difficulty scaling
- [ ] Boss rounds (every 5th or 10th wave)
- [ ] Wave countdown timer
- [ ] Between-wave preparation phase
- [ ] Victory/defeat conditions

### Visual Polish
- [x] Damage numbers (floating text above units)
- [x] Projectile visuals for ranged abilities
- [ ] Particle effects for attacks
  - [ ] Melee hit effects
  - [x] Ranged projectile (fireball implemented)
  - [ ] Critical hit effects
- [ ] Unit death animations
- [ ] Screen shake on critical hits/explosions
- [ ] Attack animations (sprite flipping/rotation)
- [ ] Ability cast animations
- **Implemented:**
  - Damage number system with float up + fade out
  - Scale based on damage amount
  - Random horizontal spread
  - Fireball projectile with smooth flight

## 🎯 Medium Priority

### Unit Traits/Synergies (TFT-style)
- [ ] Define trait types (Warrior, Mage, Ranger, Beast, Undead, etc.)
- [ ] Add trait property to UnitStats
- [ ] Trait counter UI panel
- [ ] Synergy bonus system
  - [ ] 2/4/6 of same trait = bonus
  - [ ] Different bonus types (stats, abilities, effects)
- [ ] Visual indicators for active synergies
- [ ] Trait descriptions and tooltips

### XP & Leveling System
- [ ] Player level tracking
- [ ] XP gain from winning rounds
- [ ] Level-up rewards
- [ ] Unlock additional unit slots based on level
- [ ] Better shop odds at higher levels
- [ ] Interest system (gold per 10 saved)
- [ ] Player level display UI

### Combat Improvements
- [ ] Frontline/Backline positioning logic
- [ ] Tank aggro system (enemies prefer attacking tanks)
- [ ] Ranged units prefer backline targets
- [ ] Attack priority system (low HP, high threat, etc.)
- [ ] Critical hit system
- [ ] Dodge/Evasion mechanic
- [ ] Status effects (stun, slow, poison, burn, freeze)
- [ ] Armor/Magic Resist tooltips showing % reduction

### Shop Improvements
- [ ] Lock/freeze shop (prevent auto-refresh)
- [ ] Unit reroll cost scaling with level
- [ ] Highlight units you can afford
- [ ] Show unit count remaining in pool
- [ ] Shift-click to buy and auto-place unit
- [ ] Undo last purchase button

## 📦 Low Priority / Nice to Have

### Items & Equipment
- [ ] Item drop system during combat
- [ ] Item inventory UI
- [ ] Drag items onto units to equip
- [ ] Item stat bonuses
- [ ] Item tier system (common, rare, epic, legendary)
- [ ] Item combining (2 items → 1 upgraded item)
- [ ] Special item effects (lifesteal, splash damage, etc.)

### Advanced AI
- [ ] AI difficulty levels
- [ ] Better pathfinding around allies
- [ ] Formation keeping (units stick together)
- [ ] Focus fire (multiple units target same enemy)
- [ ] Retreat logic when low HP
- [ ] Ability usage AI (smart spell casting)

### UI/UX Improvements
- [ ] Unit tooltip on hover (show all stats)
- [ ] Combat log/battle history
- [ ] Minimap for larger arenas
- [ ] Settings menu (volume, graphics, keybinds)
- [ ] Tutorial/Help system
- [ ] Unit preview in shop (show abilities)
- [ ] Drag unit to reposition during prep phase

### Meta Progression
- [ ] Save/Load system
- [ ] High score tracking
- [ ] Player statistics (games played, wins, units bought, etc.)
- [ ] Achievements system
- [ ] Daily challenges
- [ ] Unlockable unit skins

### Audio
- [ ] Battle music integration
- [ ] Sound effects for:
  - [ ] Unit attacks
  - [ ] Ability casts
  - [ ] Gold spending
  - [ ] Unit combining
  - [ ] Victory/defeat
  - [ ] UI clicks
- [ ] Volume sliders for music/SFX

### Balance & Content
- [ ] Add more unit types (need 15-20 for variety)
- [ ] Balance pass on existing units
- [ ] Add more abilities (need 10+ unique abilities)
- [ ] Different arena layouts
- [ ] Environmental hazards

### Performance & Polish
- [ ] Object pooling for projectiles/effects
- [ ] Optimize pathfinding (cache results, update less frequently)
- [ ] Particle system optimization
- [ ] Loading screen
- [ ] Transition animations between phases

## 🐛 Bug Fixes / Technical Debt
- [x] Test mana_bar_filled signal usage (working!)
- [x] Fixed mana regeneration system (battle state check)
- [x] Fixed BattleManager type casting issues
- [x] Verify all .tres files have health_regen values set
- [ ] Remove duplicate mana_changed.emit() in _set_current_mana
- [ ] Clean up unused _flash_health_bar() function
- [ ] Consistent naming conventions (snake_case vs PascalCase)

## 🎨 Asset Needs
- [ ] More unit sprites (currently using 32rogues)
- [ ] Ability/spell effect sprites
- [ ] Item icons
- [ ] UI elements (buttons, panels, borders)
- [ ] Background art for arena
- [ ] Victory/defeat screen graphics

---

## Quick Wins (Easy to implement, high impact)
1. ✅ **Damage numbers** - immediate visual feedback - DONE!
2. ⚡ Victory/defeat screen - game flow completion
3. ⚡ Wave counter UI - player knows progress
4. ⚡ Unit tooltip on hover - better info display
5. ⚡ Lock shop button - quality of life
6. ⚡ Attack sound effects - more satisfying combat

## Session Summary - November 30, 2025

### ✅ Completed Today:
1. **Damage Number System**
   - Floating damage text above units
   - Smooth float up + fade out animation
   - Scale based on damage (50+ = 1.3x, 100+ = 1.5x)
   - Random horizontal spread for visual variety

2. **Complete Ability System**
   - Base `Ability` resource class with targeting, cooldown, range
   - Auto-cast when mana reaches max
   - Range-based targeting (units out of range can't be targeted)
   - Mana consumption and cooldown management
   
3. **Active Abilities Implemented**
   - **Fireball**: Single target, 100 damage, 200 range, 3s cooldown, projectile visual
   - **Heal**: Self-heal, 30 HP, 5s cooldown
   - **Arcane Explosion**: AOE all enemies, 25 damage, 4s cooldown

4. **Passive Ability System**
   - Base `PassiveAbility` class for stat modifications
   - Support for: HP regen, mana regen, damage, armor, max HP bonuses
   - **Warrior's Endurance**: +20% health regen for Bjorn

5. **Projectile System**
   - Smooth movement toward target
   - Hit detection and damage application
   - Visual feedback on impact
   - Color customization per ability

6. **Bug Fixes**
   - Fixed mana regeneration (only during BATTLE state)
   - Fixed BattleManager type casting errors
   - Added proper null checks for battle state
   - Verified .tres files have correct stat values

### 🎯 Next Session Priorities:
1. **Wave System** - Automatic enemy spawning in progressive waves
2. **Particle Effects** - Melee hits, critical strikes, explosions
3. **Victory/Defeat Screen** - End game UI
4. **More Abilities** - Stun, slow, damage over time effects

---
*Last Updated: November 30, 2025 - Major progress on ability system!*
