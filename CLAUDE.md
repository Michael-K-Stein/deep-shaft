# Deep Shaft — working notes

An idle mining game for the Garmin Venu 2 family, written in Monkey C for
Connect IQ. The game lives at the repository root: `source/`, `resources/`,
`manifest.xml`, `monkey.jungle`.

## Commands

```sh
tools/verify.sh          # every check that does not need the SDK — run this first
tools/build.sh           # build all three devices, strict type checking
tools/build.sh venu2     # build one
tools/build.sh --fetch-sdk   # download the SDK into build/sdk, then build
```

`tools/build.sh` needs `java` and a Python 3. It finds the SDK via `CIQ_SDK`,
falling back to `build/sdk`. On this machine:

```sh
export CIQ_SDK=~/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2
```

Output is `build/venu2.prg`, `build/venu2s.prg`, `build/venu2plus.prg`. Sideload
by copying a `.prg` into `GARMIN/APPS/` on a watch plugged in over USB.

There is no test runner and no emulator in this loop. The checks in
`tools/verify.sh` are the test suite; `--typecheck 3 --warn` is the other half.
A change is "verified" when both pass — say so plainly, and do not claim
anything about on-watch behaviour that was not actually run on a watch.

## Traps

These have each cost real debugging time. Check them before writing code.

**`FONT_NUMBER_*` faces are digit-only.** They carry `0-9`, `:`, `.` and little
else. A letter drawn in one renders as *nothing at all*, silently — which is how
the main screen displayed `1.23` where it meant `1.23M` for months. Never pass a
`Fmt.big()` string straight into a numeric font. Use `Theme.bigValue()`, which
splits digits from magnitude suffix and draws the suffix in a text font.

**The screen is round.** Corners do not exist. Anything positioned near the top
or bottom has far less usable width than the nominal screen size; use
`Theme.chordHalfWidth(radius, dy)` to find the real width at a given height.
`tools/check_layout.py` reproduces each screen's arithmetic and asserts it fits
on both 416×416 and 360×360 — extend it when you add a screen.

**Do not hard-code text offsets.** Row layouts must come from
`dc.getFontHeight()` / `dc.getTextWidthInPixels()`. Guessed offsets pushed the
crew rows' second line through the bottom of their panel, and put the milestone
badge underneath the price.

**`private` is not valid at module scope.** It works inside a `class`, not
inside a `module`. The compiler's error for this is unhelpful
(`extraneous input 'private'`).

**Balance constants are mirrored in Python.** `tools/simulate_economy.py` keeps
a copy of everything in `source/Balance.mc`. That copy is what makes the
difficulty-curve claims checkable, and it silently rots the moment someone
tunes one file and not the other, so `tools/check_constants.py` compares them
and `tools/verify.sh` runs it. Change balance in both, or the check fails.

**Saves must stay loadable.** `GameState.SAVE_VERSION` gates the whole save:
a mismatch discards the player's progress. Adding a *new* key is backward
compatible, because every reader has a default — do that instead of bumping the
version whenever the old data is still meaningful.

## Shape of the code

`DeepShaftApp` owns one `GameState`; views never mutate its fields directly,
they call the `buy` / `dig` / `detonate` / `claim` helpers so the invariants
stay in one place. Every screen extends `GameView`, which owns the frame timer
and advances the simulation from *wall-clock* time — so income never depends on
how often a view happens to redraw. Exactly one such timer runs at a time.

| File | What it holds |
| --- | --- |
| `Balance.mc` | Every tuning number. Change the curve here and nowhere else. |
| `GameState.mc` | The simulation, and all persistence. |
| `Theme.mc` | Palette and shared drawing primitives. |
| `Fmt.mc` | Number and duration formatting. |
| `*View.mc` / `*Delegate.mc` | One screen and its input, paired. |

## House style

Comments explain *why*, not what — the reasoning behind a constant or an
approach, not a restatement of the line below. Several constants in
`Balance.mc` carry a paragraph on what happens if they are wrong; keep that up
when adding more. Match the surrounding density rather than adding a comment to
every line.
