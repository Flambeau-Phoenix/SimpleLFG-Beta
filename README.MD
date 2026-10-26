<h1 align="center">SimpleLFG</h1>

<p align="center">
  <strong>Find your next group in Farever.</strong><br>
  A recruiting board, cross-server listings, private messages and quick friend and party tools.
</p>

<p align="center"><img src="docs/media/simplelfg-wordmark.png" alt="SimpleLFG" width="360"></p>

<p align="center">
  <a href="dist/hlx"><b>Install files (v1.1)</b></a> ·
  <a href="https://webgameuniverse.com/lfg">Public board</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="docs/ACCEPTANCE_v1.1.md">Acceptance run</a>
</p>

SimpleLFG is a standalone interface mod for **Farever**, built on the [HLX Modding Framework](https://hlx-framework.github.io/).
**SolarFlare is not required.** Posting, whispering, friend requests, party invitations and leaving a party are always
explicit actions, and the other player always accepts through the game's normal prompts.

## Install

1. Install [HLX](https://github.com/hlx-framework/hlx-core/releases) if you do not have it.
2. Close Farever and copy the [`hlx`](dist/hlx) folder from `dist` into the **Farever game folder**, merging with the
   existing `hlx` folder. It carries everything: the mod, the SFimgui renderer and the SFCursor input helper.
3. Start Farever and press **F5** (rebindable) or click the Chat button. Settings carry over.

Back up `hlx/plugins/sfcursor/sfcursor.hdll` first if you want to roll back; this release updates that shared helper.
The mod checks the supported game build before registering anything; see [compatibility.json](compatibility.json).

## What is new in v1.1

- A menu-bar window (File, View, Party, Help) with a tab row and an always-visible party strip.
- Browse and People are sortable, resizable tables with a docked inspector, right-click menus and keyboard control.
- Party tools: invite nearby friends, friends elsewhere and nearby players; leave with a two-click confirm from the strip,
  the Party menu or People; optional Leave chip beside the on-screen button.
- Rebindable panel key with a clash warning, and it also works while the game owns the mouse.
- The on-screen button is its own window: drag it, Lock it, make it Transparent, reset or hide it from its right-click menu.
- Right-click empty space to fit the window to its designed proportions, reset it or close it.
- The SimpleLFG wordmark, toasts for results, and a Privacy and contacts settings page.
- Fix: a malformed saved Steam ID no longer stops private messaging from connecting.

## Controls

| Action | How |
| --- | --- |
| Open or close | Panel key (default F5), the Chat button, File > Close |
| Switch page | Ctrl+1 to Ctrl+5 |
| Search, move, whisper, hide | Ctrl+F, Up/Down, Enter, Delete |
| Window menu | Right-click empty space or the title bar |
| Button menu | Right-click the on-screen button |

## Privacy

Public contact sharing is opt-in and starts off; Farever and Steam sharing are separate. Names and codes are self-reported.
Private messages are session-only and cleared on logout. Details: [docs/SOCIAL_IMPLEMENTATION.md](docs/SOCIAL_IMPLEMENTATION.md).

## Building

`src/simplelfg` is the mod's own Haxe source (with `src/simplelfg/ui`, a small interface kit adapted for this mod) and
`assets/` holds what `compile.hxml` embeds. You also need your own generated GameLib for the supported game build and
the HLX runtime sources, which are not included.

## Rights and credits

MIT licensed, see [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md). Farever and its content belong to their owners;
SimpleLFG is an unofficial community tool.
