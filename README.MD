<h1 align="center">SimpleLFG v1.1</h1>

<p align="center">
  <strong>An in-game LFG/LFM recruiting board for Farever</strong><br>
  Menu-bar window, sortable resizable tables, party tools, and quick friend and party management.
</p>

<p align="center"><img src="docs/media/simplelfg-wordmark.png" alt="SimpleLFG" width="360"></p>

<p align="center">
  <a href="https://webgameuniverse.com/lfg">Public board</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="SECURITY.md">Security</a> ·
  <a href="docs/ACCEPTANCE_v1.1.md">Acceptance run</a>
</p>

- Browse listings and people with sortable, resizable tables featuring a docked inspector, right-click menus and keyboard control.
- **No account required. Fully open source (client and relay). No SolarFlare dependency.**
- SimpleLFG is a standalone interface mod built on the **HLX Modding Framework**. The download carries everything: the mod, the SFimgui renderer and the SFCursor input helper.
- Posting, whispering, friend requests, party invitations and leaving a party are always explicit actions, and the other player always accepts through the game's normal prompts.

---

## What's new in v1.1

- A menu-bar window (File, View, Party, Help) with a tab row and an always-visible party strip.
- Browse and People are sortable, resizable tables with a docked inspector, right-click menus and keyboard control.
- Party tools: invite nearby friends, friends elsewhere and nearby players; leave with a two-click confirm from the strip, the Party menu or People; optional Leave chip beside the on-screen button.
- Rebindable panel key with a clash warning, which also works while the game owns the mouse.
- The on-screen button is its own window: drag it, Lock it, make it Transparent, reset or hide it from its right-click menu.
- Right-click empty space to fit the window to its designed proportions, reset it, or close it.
- The SimpleLFG wordmark, toasts for results, and a Privacy and contacts settings page.
- Fix: a malformed saved Steam ID no longer stops private messaging from connecting.

---

## Features and controls

- Open or close the interface with the panel key (default **F5**), the Chat button, or File > Close.
- Switch pages with **Ctrl+1 to Ctrl+5**.
- Search, move, whisper or hide with **Ctrl+F, Up/Down, Enter, Delete**.
- Open the window menu by right-clicking empty space or the title bar.
- Open the button menu by right-clicking the on-screen button.
- Settings, themes and preferences persist between sessions.

---

## Requirements

**Required:**

- Farever, game build with `hlboot.dat` SHA-256 `9f48618bbcc421458c852c298d5ebec9512bfae8a8381816e0e770803601f1ec`. SimpleLFG checks this before registering anything and stays disabled on other builds.
- HLX Modding Framework ([link](https://hlx-framework.github.io/))
- SFimgui (`sfimgui.hdll`)
- SFCursor (`sfcursor.hdll`)

> **Important:** SFimgui and SFCursor are required native plugins and must be installed in the correct HLX plugin directories. Compatible versions of both are included in `SimpleLFG-v1.1.zip`.

**SolarFlare is NOT required.**

---

## Installation

### Vortex Mod Manager

Vortex compatibility depends on the installation support configured for Farever. If your Vortex setup supports deploying HLX mods into the Farever game directory:

1. Install the HLX Modding Framework.
2. Download SimpleLFG using **Mod Manager Download**, if available.
3. Install and enable SimpleLFG through Vortex.
4. Ensure the required **SFimgui and SFCursor** plugins are installed.
5. Deploy your mods.
6. Launch Farever and press **F5**.

> **Important:** Vortex must deploy the files into the actual Farever game directory, preserving the `hlx/` folder structure. If your Vortex setup does not support this layout, use the manual installation below.

### Manual installation

1. Close Farever completely.
2. Install the HLX Modding Framework ([releases](https://github.com/hlx-framework/hlx-core/releases)).
3. Download `SimpleLFG-v1.1.zip`.
4. Extract the archive directly into your **Farever game directory**, merging with the existing `hlx` folder. It carries everything: the mod, the SFimgui renderer and the SFCursor input helper. (`dist/hlx` in this repository is the same content, unzipped.)
5. Launch Farever.
6. Press **F5** (rebindable) or click the in-game **Chat** button.

**Expected directory structure**

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

**Do not place the `.hdll` files directly inside the SimpleLFG mod directory.**

If you already have compatible versions of SFimgui or SFCursor installed, you do not need to overwrite them (back up `hlx/plugins/sfcursor/sfcursor.hdll` first if you want to roll back).

### Updating

1. Close Farever.
2. Replace the existing SimpleLFG files with the new release.
3. Keep your existing configuration directory to preserve settings.

Existing themes, templates, filters, ignores and drafts are retained.

### Uninstalling

Close Farever and remove `hlx/mods/simplelfg/`. Optionally remove the configuration directory `hlx/config/simplelfg/`, which resets your saved preferences.

**Do not remove shared HLX plugins if other installed mods depend on them.**

---

## Privacy and security

Public contact sharing is opt-in and starts off; Farever and Steam sharing are separate. Names and codes are self-reported.

- No account registration required.
- No player API keys or Steam authentication setup required.
- No automatic group joining or invitations.
- No automatic recruitment posting.
- Private messages are session-only and cleared on logout.
- Steam contact information is optional and private by default.
- Public sharing of Steam contact information requires confirmation.

Details: [SECURITY.md](SECURITY.md) and [docs/SOCIAL_IMPLEMENTATION.md](docs/SOCIAL_IMPLEMENTATION.md).

---

## Compatibility and development

SimpleLFG is developed in **Haxe 4** and compiled to HashLink bytecode.

- Fully open-source addon.
- Checks the Farever build before registering anything; the supported fingerprint is listed under Requirements.
- Uses the HLX Modding Framework.
- Does not require SolarFlare.
- Does not require a Steam restart or environment variables.

`src/simplelfg` is the mod's own Haxe source, including `src/simplelfg/ui`, a small interface kit adapted for this mod. `assets/` holds what `compile.hxml` embeds. Beside it: `server/` is the relay source (see `docs/INTERFACE.md` for how the game and the website talk to it), `tests/` and `tools/` the checks. To build you also need your own generated GameLib for the supported game build and the HLX runtime sources, which are not included.

---

## Links

- [Public board](https://webgameuniverse.com/lfg)
- [HLX Framework releases](https://github.com/hlx-framework/hlx-core/releases)
- [HLX Modding Framework](https://hlx-framework.github.io/)

---

## Credits and disclaimer

- SimpleLFG is an unofficial, community-developed modification for Farever.
- It is not affiliated with, sponsored by, or endorsed by Farever's developers or publisher.
- Built using the **HLX Modding Framework**, with SFimgui and SFCursor.
- Game names, trademarks and assets remain the property of their respective owners.
- **SimpleLFG is open source and distributed under the MIT License.** See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).
