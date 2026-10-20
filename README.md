# Ink Legends

Turn-based aim-and-throw with pen-and-ink stickmen. Godot 4.7, built for desktop and phones.

## Run it

Open `project.godot` in Godot 4.7 and press F5, or press **Ctrl+Shift+B** in VS Code.

## Tests

```
godot --headless --path . -s res://tests/run_tests.gd
```

These cover the throw maths (with wind and the boomerang's curve), hit zones and bonuses, the AI aiming around obstacles, obstacle layouts and damage, maps, the tournament ladder, Target Practice, coins, achievements, the daily challenge and the shop. They also play a full AI vs AI match. They use a scratch save, so your progress is never touched.

## What's in it

- **Modes:** vs AI (Easy, Normal or Hard), Tournament (4 rounds ending in a Champion shadow boss, saved between sessions), 1v1 on one device, Target Practice, and a daily challenge.
- **8 fighters:** hammer, slingshot, spear, bow, bomb, boomerang, axe and plunger. Each has a once-per-match special.
- **6 maps:** Sunset Colosseum, Frozen Peaks, Lava Forge, Pirate Cove, Neon Rooftops and Sky Islands.
- **Each turn:** wind, head, body and leg hits, Sky Shot and combo bonuses, destructible and drifting obstacles, and supply crates.
- **Feel:** Verlet stick ragdolls, a slow-mo headshot cam, stuck weapons, generated music and sound effects.
- **Progression:** coins, fighter unlocks, ink and trail cosmetics, per-fighter stats, 12 achievements.

## Where things are

- `data/` holds fighters, weapons and maps as `.tres` files.
- `scripts/match/rules.gd` has the throw maths, shared by projectiles, the aim guide and the AI.
- `scripts/match/match_controller.gd` runs matches, the tournament, practice and payouts.
- `scripts/match/hud.gd` builds every screen. `scripts/ui/` holds the UI kit.
- `scripts/fighter/` has the stickman, its hitboxes and the ragdoll.
- `scripts/autoload/` has Audio, Save (settings and progress) and Device (phone tweaks).
- `scripts/tools/` holds the sound effect and music generators.
