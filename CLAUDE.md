# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A 2D platformer built with **Godot Engine 4.7** (Standard build — no C#/.NET), using the Pixel Adventure 1 art pack. Player picks a character, dodges hazards (spikes, saws, patrolling enemies), collects fruit, hits checkpoints, reaches the goal flag. UI, README and CONTRIBUTING are written in Vietnamese.

## Project layout gotcha

The Godot project root is **`game/`**, not the repo root. Import `game/project.godot` in Godot. The repo root holds only docs plus loose asset archives (`*.zip`, `*.rar`, extracted pack folders like `adve/`, `Kings and Pigs/`, `Free Smoke Fx Pixel 2/`) that are raw source art, not wired into the project — leave them alone unless a task is about importing new assets.

## Running / testing

- No CLI build or automated tests. Open `game/project.godot` in the Godot 4.7 editor and press F5. Main scene is `res://ui/main_menu/main_menu.tscn`.
- `godot` is not on PATH in this environment; you cannot run the game headless here. Reason about `.gd`/`.tscn` files directly and describe what to verify in-editor.
- After any folder-structure change, CONTRIBUTING requires opening the project in the editor once so it rescans and re-saves scenes flagged dirty.

## Architecture

**Feature-based folders, not type-based.** Each feature folder (`player/`, `levels/level_N/`, `objects/<thing>/`, `ui/<screen>/`) contains its own `.tscn` + `.gd` + `sprites/`. Only put an asset in `game/shared/` or `game/ui/shared/` if ≥2 features actually reference it (grep the path in `*.tscn`/`*.gd` to confirm).

**Autoloads (`game/core/`, registered in `project.godot [autoload]`):**
- `Events` (`events.gd`) — global signal-bus autoload: **signals only, no state or logic**. Gameplay `emit`s; HUD / SaveManager / achievements `connect`. Keeps gameplay decoupled from UI/Save. Not yet wired (skeleton from ROADMAP Phase 0).
- `GameManager` (`game_manager.gd`) — run state that survives scene changes: `selected_character`, `current_level_id`, `score`, `hearts`, `respawn_position`/`has_checkpoint`, `last_result` (`"win"`/`"lose"`), and `_elapsed` playtime (accumulated from `delta`, paused-aware). `start_new_run()` resets everything; `set_checkpoint()` also refills hearts. `MAX_HEARTS` is 3 — changing it requires manually adding/removing Heart icon nodes in `ui/hud/hud.tscn`.
- `SceneTransition` (`scene_transition.tscn`) — **always** change scenes via `SceneTransition.goto(path)`. It unpauses, plays the fade animation, swaps the scene, never leaves the tree paused.
- `SaveManager` (`save_manager.gd`) — persists `completed_levels`, `high_scores`, `best_times` to `user://save_data.json` as JSON. `is_level_unlocked()` gates level N on having completed level N-1. `record_result()` is called from the end screen.

**Non-autoload global classes (`class_name`):**
- `LevelData` (`core/levels.gd`) — the ordered `LEVELS` array (id / name / scene path) is the single source of truth for level order and unlock chain. Add a level = add one entry here (after creating the scene). Also holds `format_time()`.
- `CharacterData` (`core/characters.gd`) — playable roster: `NAMES` (order shown in `character_select`) + `CHARACTERS` dict (display name, per-character `sprite.offset` to align feet to the shared collision box) + path helpers for `<name>_frames.tres` / `portrait.png` in `player/sprites/<Name>/`. Roster is King + Captain (Pixel Frog CC0, have attack anims); the 4 old froggy chars (`player/sprites/Ninja Frog/` etc.) are retired from `NAMES` but their folders stay for future skins. `character_select` builds its buttons from `NAMES` in code (like `level_select`).

**Reusable components (`game/components/`, `class_name`)** — 1 job per node, attached in the scene, wired via `@export`. `HealthComponent` (Node) — hp + i-frames; pure logic, emits `died`/`health_changed`/`invincibility_started`; owner forwards to `Events`. `Hitbox` (Area2D) — deals damage, passive data holder (`damage`, `knockback_force`), `enable()`/`disable()` per attack frame. `Hurtbox` (Area2D) — receives damage, active: on `area_entered` reads `damage` from a `Hitbox` (or 1 from a plain hazard Area2D on its mask layer) → `health_component.damage()`, emits `hurt(source)`. See CONTRIBUTING.md for the collision-layer table.

**Player (`player/player.gd`)** — `CharacterBody2D`, in group `"player"`. Hand-rolled movement: gravity, double jump (`MAX_JUMPS`), wall slide + wall jump. Infinite wall-climb is blocked two ways: a short post-jump horizontal input lock (`WALL_JUMP_LOCK_DURATION`), plus `last_wall_jump_dir` — you can't wall-jump the same wall face twice until you touch the floor or the opposite wall (zig-zag between two walls still works). Health lives in a `HealthComponent` child (`$HealthComponent`, `max_hp` 3); `player.gd` connects its signals — `hit(force_reposition)` calls `health.damage(1)`, `died` → `_on_health_died` (respawn at checkpoint if any, else end screen), `health_changed` → mirrors `GameManager.hearts` + emits `Events.player_health_changed`. Player also listens to `Events.checkpoint_activated` to heal to full. `win()` sets result and transitions. Player scene has a `Hurtbox` child (layer `player_hurtbox`, mask `enemy_hitbox`) — `player.gd` connects `hurtbox.hurt` → `_on_hurt` (plays "hit"); actual damage is applied by the Hurtbox itself. `Hitbox` child is wired for attacks in Phase 2b.

**Levels** — all five level scenes (`levels/level_1`..`level_5`) share the single script `levels/level_base.gd` (`class_name LevelBase`). It sets the spawn point from `$Interactables/StartMarker` in `_enter_tree()` (before children `_ready()`), refills hearts, applies exported camera limits, detects falling off the map (`fall_death_y`), and owns the pause menu. Per-level scene tree convention: group nodes under `Interactables` (StartMarker, GoalFlag, Checkpoint), `Enemies`, `Fruits`.

**Gameplay objects (`objects/`)** — hazards/enemies are `Area2D` on the `enemy_hitbox` layer (no script logic for damage — the player's `Hurtbox` detects them); `goal_flag` calls `body.win()`; `checkpoint` calls `GameManager.set_checkpoint()` + emits `Events.checkpoint_activated`; `fruit` increments `GameManager.score`. `goal_flag`/`checkpoint`/`fruit` are on the `interactable` layer, mask `player`, and still use `body_entered`. Enemies live in `objects/enemies/<type>/`; movable enemies (`walker`, `flyer`, `spike_head`/`chaser_spike`) also carry `HealthComponent` + `Hurtbox` children (damageable in Phase 2b); pure traps (`spikes`, `saw`/`orbit_saw`, `falling_spike`) do not.

**Flow:** `main_menu` → `character_select` (sets `GameManager.selected_character`) → `level_select` (calls `start_new_run(id)`) → level scene → `end_screen` (records result, offers retry / back to level select).

## Conventions (from CONTRIBUTING.md)

- `snake_case` files/folders, `PascalCase` scene node names, `SCREAMING_SNAKE_CASE` constants. Explicit GDScript types everywhere (`var x: float`, `-> void`). Comments explain **why**, not what.
- **Never build `SpriteFrames`/`AtlasTexture` in code at runtime.** Every `AnimatedSprite2D` uses a pre-baked `.tres` `SpriteFrames` file edited via Godot's SpriteFrames panel. Scenes bake a default set so the editor shows no config warning; code only `load()`s and assigns a different `.tres`.
- Object variants that differ only by texture/animation (fruit types, etc.) get **one** base scene + one `SpriteFrames` `.tres` per variant. Set the variant via an exported `SpriteFrames` property **on the instance node** (e.g. `variant_frames` on `fruit.gd`, which is `@tool` + has a setter for live editor preview). Never override properties of deeply-nested child nodes inside an instance — Godot may silently drop them on save.
- Don't commit `.godot/` (gitignored editor cache) or junk (`.DS_Store`). Check `git status` before `git add`.

## PLAN.md

`PLAN.md` (Vietnamese) is a design brief for expanding the game toward a mini-Metroidvania (hub, dash, combat, bosses, abilities, NPCs). It explicitly says **not** to implement all listed systems by default — treat it as direction, not a task list.
