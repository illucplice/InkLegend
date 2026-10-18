# Wobble Wars

Turn-based aim-and-throw with floppy fighters. Godot 4.7, web-first.

## Run it

Open `project.godot` in Godot 4.7 and press F5, or from this folder:

```
godot --path .
```

## Tests

```
godot --headless --path . -s res://tests/run_tests.gd
```

These check the damage table, that the AI's perfect throw lands on target, that the AI gets more accurate each turn, and that a full AI vs AI match ends in a knockout.

## Where things are

- `data/` has fighters and weapons as `.tres` files. Add a fighter by adding a file, with no code changes.
- `scripts/match/rules.gd` holds the rules and the throw maths. Projectiles, the aim preview and the AI all use it.
- `scripts/match/match_controller.gd` runs the turns.
- `scripts/ai/ai_aimer.gd` is the ballistic solver plus the accuracy curve.

## Phase 1 status

This is a greybox: fighters are drawn from shapes and wobble on a spring. Phase 2 replaces them with Blender-rendered ragdolls. Specials, 2-player mode, target practice, sound and saving come in later phases.
