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
- `CharacterData` (`core/characters.gd`) — playable character names + path helpers to their baked `SpriteFrames` (`player/sprites/<Name>/<name>_frames.tres`).

**Player (`player/player.gd`)** — `CharacterBody2D`, in group `"player"`. Hand-rolled movement: gravity, double jump (`MAX_JUMPS`), wall slide + wall jump with a post-jump input lock (`WALL_JUMP_LOCK_DURATION`) that prevents infinite wall climbing. `hit(force_reposition)` subtracts one heart; hearts>0 → temp invincibility only, hearts==0 → real death (respawn at checkpoint if any, else go to end screen). `win()` sets result and transitions.

**Levels** — all five level scenes (`levels/level_1`..`level_5`) share the single script `levels/level_base.gd` (`class_name LevelBase`). It sets the spawn point from `$Interactables/StartMarker` in `_enter_tree()` (before children `_ready()`), refills hearts, applies exported camera limits, detects falling off the map (`fall_death_y`), and owns the pause menu. Per-level scene tree convention: group nodes under `Interactables` (StartMarker, GoalFlag, Checkpoint), `Enemies`, `Fruits`.

**Gameplay objects (`objects/`)** — hazards/enemies are `Area2D` that call `body.hit()` on the player; `goal_flag` calls `body.win()`; `checkpoint` calls `GameManager.set_checkpoint()`; `fruit` increments `GameManager.score`. Enemies live in `objects/enemies/<type>/`.

**Flow:** `main_menu` → `character_select` (sets `GameManager.selected_character`) → `level_select` (calls `start_new_run(id)`) → level scene → `end_screen` (records result, offers retry / back to level select).

## Conventions (from CONTRIBUTING.md)

- `snake_case` files/folders, `PascalCase` scene node names, `SCREAMING_SNAKE_CASE` constants. Explicit GDScript types everywhere (`var x: float`, `-> void`). Comments explain **why**, not what.
- **Never build `SpriteFrames`/`AtlasTexture` in code at runtime.** Every `AnimatedSprite2D` uses a pre-baked `.tres` `SpriteFrames` file edited via Godot's SpriteFrames panel. Scenes bake a default set so the editor shows no config warning; code only `load()`s and assigns a different `.tres`.
- Object variants that differ only by texture/animation (fruit types, etc.) get **one** base scene + one `SpriteFrames` `.tres` per variant. Set the variant via an exported `SpriteFrames` property **on the instance node** (e.g. `variant_frames` on `fruit.gd`, which is `@tool` + has a setter for live editor preview). Never override properties of deeply-nested child nodes inside an instance — Godot may silently drop them on save.
- Don't commit `.godot/` (gitignored editor cache) or junk (`.DS_Store`). Check `git status` before `git add`.

## PLAN.md

`PLAN.md` (Vietnamese) is a design brief for expanding the game toward a mini-Metroidvania (hub, dash, combat, bosses, abilities, NPCs). It explicitly says **not** to implement all listed systems by default — treat it as direction, not a task list.
