# Personal Resource Options

Personal Resource Options (PRO) is a World of Warcraft addon that enhances the built-in Personal Resource Display (PRD) with customizable text overlays, per-bar visibility controls, and a full profile system. All settings are exposed through the native Blizzard Settings panel.

## Features

### Visibility Controls
- **Show/Hide the entire display** with a single master toggle
- **Individual toggles** for the health bar, power bar, alternate power bar, and class resource frame
- **Display scale** slider (50–400%) for the whole PRD frame

### Text Overlays
Each bar has an independent text overlay with full control over:
- **Anchor point** — Left, Center, Right
- **Font** — Expressway (bundled), Friz Quadrata, Arial Narrow, Morpheus, Skurri
- **Font size** — 6–32pt slider
- **Outline** — None, Outline, or Thick Outline (single dropdown)
- **Monochrome** — optional anti-aliasing toggle (combines with any outline mode)
- **Text color** — native Blizzard color picker

**Health bar text** — displays current health (abbreviated)

**Power bar text** — displays current primary resource; updates on power type change and Druid form shifts

**Alternate power bar text** — class-specific secondary resources with configurable decimal places (0–2):
- Demon Hunter — Soul Fragments (Devourer spec)
- Evoker — Ebon Might remaining duration (Augmentation spec)
- Monk — Stagger amount (Brewmaster spec)

### Class Resource Frame
- **Scale** slider (50–400%) and **X/Y offset** sliders for the class frame widget
- Supported for: Paladin, Rogue, Death Knight, Mage, Warlock, Monk, Druid, Evoker

**Death Knight rune cooldowns** — countdown text on each rune while it is recharging (raw integer seconds), with automatic sub-pixel positioning correction based on the selected outline mode

### Profiles
- **Multiple named profiles** — create, rename, delete, switch per character
- **Copy from** — duplicate another profile's settings into the current one
- **Export / Import** — share profiles as Base64-encoded strings (CBOR serialization)
- **Per-character assignment** — each character remembers its active profile
- **Class-specific settings** — class frame and rune cooldown settings are stored per class within each profile, so a single profile works across alts
- The Default profile cannot be deleted or renamed

## Usage

Open the settings panel via:
- **Slash command**: `/pro`
- **Addon Compartment**: click the PRO icon in the minimap compartment bar
- **Blizzard Settings**: Game Menu → Settings → AddOns → Personal Resource Options

If opened during combat, the panel will automatically appear when combat ends.

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
