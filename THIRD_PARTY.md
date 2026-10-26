# Dependencies and notices

- HLX runtime 0.0.9: hlx-framework, MIT. Source snapshot in `deps/hlx-runtime`; original license copied to `licenses/HLX-runtime-MIT.txt`.
- hl-imgui 0.0.5 / SFimgui fork: bindings derived from laymain/farever-mods, whose package metadata declares MIT. The custom native renderer is the exact existing shared SFimgui build. `licenses/hl-imgui-MIT.txt` contains the MIT terms; upstream metadata is preserved in `deps/hl-imgui/haxelib-upstream.json`.
- Dear ImGui: Omar Cornut, MIT; `licenses/Dear-ImGui-MIT.txt`.
- cimgui: cimgui contributors, MIT; original license in `licenses/cimgui-MIT.txt`.
- xxHash: Yann Collet, BSD 2-Clause; `licenses/xxhash-BSD.txt`.
- format 3.8.0: Haxe Project Contributors, BSD 2-Clause; `licenses/format-BSD.txt`. Local source and upstream metadata in `deps/format`; used to decode embedded launcher PNGs before drawing.
- SFCursor shared helper: MIT; the separately packaged source snapshot and its license are in `native/sfcursor`. Existing ExtraBars/shortcut exports are preserved for compatibility; SimpleLFG does not activate them.
- Noto Sans Regular (optional renderer dependency package): Copyright 2015 Google Inc. All Rights Reserved. SIL Open Font License 1.1. Copyright and license are embedded in the unmodified font's name table and reproduced in `licenses/NotoSans-OFL-1.1.txt`. Official text: https://openfontlicense.org/open-font-license-official-text/ . Other installed/custom fonts are not packaged.
- GameLib contains generated interoperability declarations from the supported installed Farever bytecode. Activity names and the bounded boss-loot catalogue are selected from that build's prefab/data.cdb records. full game bytecode, full data.cdb, and asset packs are excluded from release archives. Farever names/data remain with their respective owners. The embedded loot atlas contains only 101 covered item portraits extracted from the supported current game PAK, resized with transparency retained; these images remain the property of their respective game rights holders.
- Four launcher PNG designs were supplied by the project owner. They retain their original transparency and proportions. Their inclusion does not assign ownership of artwork to the addon authors or extend the addon source license to third-party artwork.

The addon source's MIT license does not replace the individual dependency/font licenses.

