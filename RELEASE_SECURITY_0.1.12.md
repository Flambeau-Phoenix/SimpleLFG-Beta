# SimpleLFG 0.1.12 — final security/release review

Generated: 2026-10-26T04:06:56.049298+00:00

Accepted bytecode SHA-256: `3109312EB6CC925C7AAC415040F6122AB8959766B6A0C3DAC33B11B6950D1A0C`.
The user confirmed that everything works in the installed 0.1.12-test build. The release carries those exact bytes; no recompilation occurred.

## Fresh Snyk results

- CLI 1.1308.3, organization flambeau-phoenix; 129 allowlisted first-party files submitted.
- Code: **0 high, 0 medium, 12 low**, no ignored findings. Exit code 1 reflects the remaining low findings; this is not a zero-finding scan.
- Open Source: **13 Python dependencies, no known vulnerable paths**, exit code 0.
- No source findings reported in the scanned Python relay or PHP/JavaScript website runtime.
- Haxe is absent from the reported supported-language coverage. Its acceptance rests on the existing offline/native checks and the user-operated game test, not this SAST result.

## Change prompted by the final pass

The initial final-pass scan flagged command execution in the local wire fixture. The launcher now runs only the fixed build/RelayWireProbe.hl through HashLink on PATH, rejecting other executables, scripts and bytecode. Six boundary tests pass; the medium finding is absent on rescan. This changed a local test tool only.

## Remaining low findings

| Location | Finding | Review |
|---|---|---|
| `simplelfg/tools/abi/Program.cs:12` | Path Traversal | Local ABI extractor: operator chooses the output evidence directory; not shipped or invoked by the mod/server. |
| `simplelfg/tools/test_lfg_admin_ui.mjs:9` | Cleartext Transmission - HTTP Instead of HTTPS | Synthetic HTTP fixture bound exclusively to 127.0.0.1, ephemeral port; never deployed. |
| `simplelfg/tools/test_lfg_board.mjs:10` | Cleartext Transmission - HTTP Instead of HTTPS | Synthetic HTTP fixture bound exclusively to 127.0.0.1, ephemeral port; never deployed. |
| `simplelfg/tools/test_lfg_home_lava.mjs:6` | Cleartext Transmission - HTTP Instead of HTTPS | Synthetic HTTP fixture bound exclusively to 127.0.0.1, ephemeral port; never deployed. |
| `simplelfg/tools/abi/audit_native_imports.py:30` | Path Traversal | Local byte/PE audit: operator chooses input and output paths; never exposes a request-driven file interface. |
| `simplelfg/tools/abi/audit_native_imports.py:30` | Path Traversal | Local byte/PE audit: operator chooses input and output paths; never exposes a request-driven file interface. |
| `simplelfg/tools/build_boss_loot.py:109` | Path Traversal | Operator-selected local input; output resolves under the project root. Scanner finding retained. |
| `simplelfg/tools/build_boss_loot.py:116` | Path Traversal | Operator-selected local input; output resolves under the project root. Scanner finding retained. |
| `simplelfg/tools/abi/audit_native_imports.py:30` | Path Traversal | Local byte/PE audit: operator chooses input and output paths; never exposes a request-driven file interface. |
| `simplelfg/tools/abi/read_activity_prefabs.py:69` | Path Traversal | Local read-only game-data extraction with operator-selected output; not a deployed service. |
| `simplelfg/tools/package.py:39` | Path Traversal | Local trusted manifest packaging; paths resolve under dist/project and hashes are checked. Scanner findings retained. |
| `simplelfg/tools/package.py:47` | Path Traversal | Local trusted manifest packaging; paths resolve under dist/project and hashes are checked. Scanner findings retained. |

No .snyk suppression or severity filter was used for the full scan. The low findings remain disclosed for local operators; the release archive contains neither these development tools nor a public file/command interface.

## Evidence and boundaries

Raw evidence: build/snyk-final-0.1.12/code.json and code.sarif (initial), code-round2.json and code-round2.sarif (final), dependencies.json, snapshot.json and snapshot-round2.json.
Credentials, live configuration, private databases/messages/logs, vendored dependencies and game data were excluded before submission.
The pre-release verification includes interpreter/native behavioral suites, 39 backend regressions, native loopback wire checks and 92 SFimgui/12 HLX/3 SFCursor static imports. The final pass did not recompile or inspect the running game.
A Snyk scan does not prove absence of all vulnerabilities or native ABI errors. Distributed anonymous abuse and self-reported player identity remain limitations of the service.

## Release artifacts

SimpleLFG-0.1.12.zip is the client addon. Shared HLX/SFimgui/SFCursor dependencies are unchanged; dependency archive hashes are listed in manifest-release-0.1.12.json.
The runtime still identifies its build as 0.1.12-test. Release metadata explicitly records that identity so the binary remains exactly the one accepted in-game.
Earlier test archives are preserved. No GitHub publishing, website deployment, installed-file replacement or game control was performed for this final release pass.
