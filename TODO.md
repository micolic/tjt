# TODO List - TJT Game Development

## 🔥 High Priority

### Ability System
- [ ] Implement ability casting mechanism when mana is full
- [ ] Create base Ability class/resource
- [ ] Add ability button/hotkey triggering
- [ ] Visual effects for ability activation
- [ ] Cooldown system for abilities
- [ ] Create sample abilities (fireball, heal, AOE damage, stun, etc.)
- [ ] Ability targeting system (self, enemy, area)
- [ ] Mana consumption on ability use

### Wave System
- [ ] Enemy wave spawner component
- [ ] Wave configuration (number of enemies, types, spawn positions)
- [ ] Progressive difficulty scaling
- [ ] Boss rounds (every 5th or 10th wave)
- [ ] Wave countdown timer
- [ ] Between-wave preparation phase
- [ ] Victory/defeat conditions

### Visual Polish
- [ ] Damage numbers (floating text above units)
- [ ] Particle effects for attacks
  - [ ] Melee hit effects
  - [ ] Ranged projectile trails
  - [ ] Critical hit effects
- [ ] Unit death animations
- [ ] Screen shake on critical hits/explosions
- [ ] Attack animations (sprite flipping/rotation)
- [ ] Ability cast animations

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
- [ ] Test mana_bar_filled signal usage
- [ ] Remove duplicate mana_changed.emit() in _set_current_mana
- [ ] Verify all .tres files have health_regen values set
- [ ] Clean up unused _flash_health_bar() function
- [ ] Add null checks for battle_manager in more places
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
1. ⚡ Damage numbers - immediate visual feedback
2. ⚡ Victory/defeat screen - game flow completion
3. ⚡ Wave counter UI - player knows progress
4. ⚡ Unit tooltip on hover - better info display
5. ⚡ Lock shop button - quality of life
6. ⚡ Attack sound effects - more satisfying combat

## Next Session Focus
**Suggestion:** Start with Ability System + Damage Numbers + Wave System
- These 3 features will make the game feel much more complete
- Ability system uses existing mana regeneration
- Damage numbers are quick visual polish
- Wave system provides actual gameplay loop

---
*Last Updated: November 30, 2025*
