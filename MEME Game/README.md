# Trunk Tales

A digital adaptation of *Trunk Tales*, a card-based strategy board game designed in collaboration with the **Management and Ecology of Malaysian Elephants (MEME)** initiative — a research project by the University of Nottingham Malaysia and the Department of Wildlife and National Parks of Peninsular Malaysia (PERHILITAN). The game explores human–elephant conflict and the trade-offs between conservation, plantation use, and community needs.

Learn more about MEME: <https://www.meme-elephants.org>

## Requirements

- **Godot Engine 4.5** (or compatible 4.x). Download from <https://godotengine.org/download>.

## How to Run

1. Launch Godot Engine.
2. Click **Import** and select the `project.godot` file in this folder (or drag `project.godot` onto the Godot executable).
3. With the project open, press the **Play** button (top-right) or hit `F5`. The game launches into the Main Menu.

## Gameplay Overview

- Each player takes on a unique **role** — Conservationist, Village Head, Plantation Owner, Land Developer, Environmental Consultant, Ecotourism Manager, Wildlife Department, Researcher, or Government — each with its own **win condition** and **special ability**.
- On your turn, play a card from your 5-card hand to shape the board: add / remove / move elephants and villagers, convert tiles between **Forest**, **Plantation**, and **Human-Dominated**, or trigger role-specific effects.
- Cards come in four colours:
  - **Green** — helpful/protective actions
  - **Yellow** — neutral, double-edged
  - **Red** — harmful or destructive
  - **Black** — mandatory-play event cards
- The first player to simultaneously satisfy every part of their role's win condition wins.

## Controls

| Input | Action |
|---|---|
| **Left-click drag** (on board) | Rotate camera around the board |
| **Mouse wheel** | Zoom in / out |
| **Q / E** | Snap-rotate the camera 90° |
| **Left-click card** | Select card; click again on the preview to play |
| **Left-click tile** (during a card effect) | Confirm tile selection for the active effect |
| **Esc** | Open / close the Pause menu |
| **Played Cards button** (bottom-left) | Review recent cards played by each player |

## Project Layout

- `scenes/` — main scenes (`MainMenu`, `CardTable`, `RoleSelection`, `ScenarioSelect`, `How to Play`, `PauseMenu`, `Card`)
- `scripts/` — game logic. Key autoloads: `GameState`, `CardData`, `ScenarioData`, `RoleEffect`.
- `scripts/Card Table/bot.gd` — bot decision logic (EASY / MEDIUM / HARD difficulty).
- `scripts/Card/CardEffects.gd` — card-effect dispatcher and state machine.
- `assets/` — textures (cards, tiles, pieces, UI).
