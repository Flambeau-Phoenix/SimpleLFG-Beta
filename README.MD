<h1 align="center">SimpleLFG</h1>

<p align="center">
  <strong>Find your next group in Farever.</strong><br>
  An in-game recruiting board, cross-server listings and private messages.
</p>

<p align="center">
  <img alt="Release v1.0b" src="https://img.shields.io/badge/release-v1.0b-orange.svg">
  <img alt="Game Farever" src="https://img.shields.io/badge/game-Farever-orange.svg">
  <img alt="Requires HLX" src="https://img.shields.io/badge/requires-HLX%20framework-blue.svg">
  <img alt="Status beta" src="https://img.shields.io/badge/status-beta-yellow.svg">
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-green.svg">
</p>

<p align="center">
  <a href="dist/SimpleLFG-v1.0b.zip"><b>Download v1.0b</b></a> ·
  <a href="https://webgameuniverse.com/lfg">Public board</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="SECURITY.md">Security</a>
</p>

<p align="center"><img src="docs/media/simplelfg.png" alt="SimpleLFG" width="500"></p>


SimpleLFG is a standalone interface mod for **Farever**, built on the
[HLX Modding Framework](https://hlx-framework.github.io/). Browse recruiting
messages, find players for a run, advertise your group and keep conversations
in one place. **SolarFlare is not required.**

No player API keys, environment variables, Steam code or Steam restart are
needed. Posting and messaging use explicit actions; SimpleLFG does not join
groups or send invitations automatically.

**Contents:** [Install](#install) · [Quick controls](#quick-controls) ·
[Features](#features) · [Privacy and security](#privacy-and-security) ·
[For developers](#for-developers) · [Rights and credits](#rights-and-credits)

## Install

**Requirements:** Farever, compatible **HLX**, **SFimgui** and **SFCursor**.
The addon checks the supported game build before registering its hook or UI.
The addon refuses to load on unsupported builds.

1. Close Farever and download [SimpleLFG-v1.0b.zip](dist/SimpleLFG-v1.0b.zip).
2. For a fresh installation, install [HLX](https://github.com/hlx-framework/hlx-core/releases),
   then extract the matching [SFimgui](dist/SimpleLFG-SFimgui-dependency-0.1.1.zip)
   and [SFCursor](dist/SimpleLFG-SFCursor-dependency-0.1.1.zip) packages into the game folder.
   Existing compatible shared helpers can be kept.
3. Extract the addon ZIP directly into the **Farever game root**, producing:

```text
Farever/
└── hlx/
    ├── mods/
    │   └── simplelfg/
    │       └── simplelfg.hl
    └── plugins/
        ├── sfimgui/
        │   ├── sfimgui.hdll
        │   └── fonts/
        └── sfcursor/
            └── sfcursor.hdll
```


4. Launch Farever and press **F5**, or click **Chat** beside the game's bottom-right menu.
   Free the game cursor to interact with the panel.
![SimpleLFG](MoltenLFG.png) 
> [!NOTE]
> **Updating:** replace the addon with Farever closed. Existing drafts, templates,
> themes, filters and ignores are retained. The shared dependency packages are
> unchanged from 0.1.1; compare fingerprints before replacing another mod's helpers.

**Removing SimpleLFG:** close Farever and remove `hlx/mods/simplelfg`.
Preferences are stored separately in `hlx/config/simplelfg/config.json`; keep
that folder to retain your setup. Keep shared helpers needed by other mods.

## Quick controls

| Control | Action |
|---|---|
| **F5** | Open or close all SimpleLFG windows. |
| **Chat button** | Open the main panel; hide the button in General if preferred. |
| **Browse** | Search local recruiting messages and cross-server listings. |
| **Post** | Review and manually publish an LFG or LFM post. |
| **Messages** | Read conversations, compose a whisper or send a private relay message. |
| **Boss loot** | Open the independent loot browser. |

The main panel starts closed. F5 works in either cursor mode; the game's pointer
mode determines mouse interaction. Logout or changing sessions clears live
chat history and closes the windows.

## Features

### Recruiting board

- Browse **All**, **Groups** and **Players**, with target, player and age sorting.
- Search multiple words in any order across activity, note, host and class.
- Recognize recruiting messages and target mentions across enabled chat channels.
- Green **Context Detected** and red **No Context Detected** labels explain why a
  message appears. Context detection is not confirmation of available party slots.
- Hide, ignore and watch entries, and review recent messages from a selected player.
- Use editable recruiting phrases, exclusions and target aliases to tune recognition.

### Posts and conversations

- Publish **LFG** or **LFM**, with activity, Normal/Veteran/Heroic difficulty,
  notes, Bonus Runs and optional Warrior/Mage/Priest/Rogue class metadata.
- Set party members and capacity through dropdowns, with five reusable templates.
- Review the exact outgoing text before sending. Reminders never post automatically.
- Use native game chat and whispers, or explicitly choose **Cross-server** to publish
  on the [public board](https://webgameuniverse.com/lfg).
- Private relay messaging uses automatically issued session credentials; incoming
  text does not automatically open links or Steam profiles.

### Boss loot and personal settings

- Browse **14 released bosses**, **26 reachable boss-loot tables** and **101 items**,
  with portraits, rarity, descriptions, source restrictions and difficulty choices.
- Ordinary creature/global loot and unreleased bosses are excluded. Raw table weights
  are not presented as per-kill drop chances.
- Choose Midnight, Slate, Warm or Custom themes, text scale and high contrast.
- Alerts and sound start off. Enable watches when you want recruiting notifications.
- Move and resize the main panel and independent loot window; settings save automatically.

## Privacy and security

Steam contact is optional, blank on a fresh setup and not shared publicly by default.
Public sharing requires confirmation. Local received-message history stays in memory
and is not uploaded or written to preferences. Cross-server features use HTTPS and
session credentials kept in memory; player names and Steam codes remain self-reported.

See [SECURITY.md](SECURITY.md) and [server/PRIVACY.MD](server/PRIVACY.MD) for the security model and relay data handling.

## For developers

Full addon source and pinned dependencies are included. The optional relay server
source is separate from the game addon.

| Path | Contents |
|---|---|
| `src/simplelfg/` | Haxe addon source. |
| `deps/` | Vendored build dependencies. |
| `assets/` | Embedded catalogs, artwork and the loot atlas. |
| `native/` | Source for the shared SFCursor helper. |
| `server/` | Python relay behind the public board, with tests. |
| `tests/`, `tools/` | Behavioral tests and source lint. |
| `dist/` | Release ZIP and dependency packages. |

Build with **Haxe 4.3.7**, from this repository root:

```powershell
New-Item -ItemType Directory -Force build
haxe compile.hxml
```

The build uses local pinned dependencies, without global Haxelib registration,
and writes `build/simplelfg.hl`. Stock HashLink runs isolated tests; the addon
itself runs inside Farever's HLX host.

## Feedback

Report the release version, Farever build, steps to reproduce and whether the
problem involves local chat, cross-server listings or private messages. Omit
private messages and credentials from public reports. Use the repository's
private security reporting channel or contact the maintainer privately for
sensitive findings.

## Rights and credits

SimpleLFG is an **unofficial** fan-made mod and is not affiliated with or endorsed
by Farever's developers or publisher. Game names, assets and trademarks belong
to their respective owners.

Addon source is licensed under the [MIT license](LICENSE). Dependencies, fonts
and third-party/game artwork retain their own licenses and rights; see
[THIRD_PARTY.md](THIRD_PARTY.md) and `licenses/`.

Built on the [HLX Modding Framework](https://hlx-framework.github.io/) by
[laymain](https://github.com/laymain), with SFimgui and SFCursor.

