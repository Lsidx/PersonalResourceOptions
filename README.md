# Personal Resource Options

Personal Resource Options (PRO) is a World of Warcraft addon that enhances the built-in Personal Resource Display (PRD) with customizable text overlays and per-bar visibility controls. All settings are exposed through the native Blizzard Settings panel.

## Features

### Visibility Controls
- **Show/Hide the entire display** with a single master toggle
- **Individual toggles** for the health bar, power bar, alternate power bar, and class resource frame
- **Display scale** slider (50–200%) for the whole PRD frame

### Text Overlays
Each bar has an independent text overlay with full control over:
- **Anchor point** — 9 positions (top-left through bottom-right)
- **Font** — Expressway (bundled), Friz Quadrata, Arial Narrow, Morpheus, Skurri
- **Font size** — 6–32pt slider
- **Outline** — thin outline, thick outline, or monochrome rendering
- **Text color** — native Blizzard color picker

**Health bar text** — displays current health (abbreviated)

**Power bar text** — displays current primary resource; updates on power type change and Druid form shifts

**Alternate power bar text** — class-specific secondary resources:
- Demon Hunter — Soul Fragments
- Evoker — Essence / Ebon Might stacks
- Monk — Stagger

### Class Resource Frame
- **Scale** and **X/Y offset** sliders for the `prdClassFrame` widget
- Supported for: Paladin, Rogue, Death Knight, Mage, Warlock, Monk, Druid, Evoker

**Death Knight rune cooldowns** — countdown text on each rune while it is recharging (raw integer seconds)

## Usage

Open the settings panel via:
- **Slash command**: `/pro`
- **Addon Compartment**: click the PRO icon in the minimap compartment bar
- **Blizzard Settings**: Game Menu → Settings → Combat → Personal Resource Options

All settings take effect immediately without a reload.

## Installation

1. Download and extract the `PersonalResourceOptions` folder.
2. Place it in `World of Warcraft/_retail_/Interface/AddOns/`.
3. Enable the addon at the character select screen.

## Compatibility

- **Interface**: 120001 (The War Within / Midnight)
- **Taint-safe**: no restricted API calls; compatible with raid and Mythic+ environments
- **Dependencies**: None (Blizzard_Settings and Blizzard_PersonalResourceDisplay load automatically)

## Addon Details

| Field | Value |
|---|---|
| Author | Lousid |
| Saved Variables | `PersonalResourceOptionsDB` |
| Category | Combat |
| Slash Command | `/pro` |
