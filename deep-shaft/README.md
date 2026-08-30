# Deep Shaft

An idle mining tycoon for the Garmin Venu 2, built with Connect IQ / Monkey C.

The concept is lifted from the idle-game ads everyone has scrolled past: hire a
crew that keeps digging while you are away, sink the profits into a deeper
shaft, then blow the whole mine up for a permanent multiplier and do it again,
faster. Every beat of that ad formula is here — the number that never stops
going up, the "while you were away" pile of gold, the shop where the next
purchase is always just out of reach, and the prestige reset that makes
starting over feel like progress.

## The loop

| Mechanic | What it does |
| --- | --- |
| **Swing** | Tap the screen or press START to mine by hand. Worth `1 + 10%` of your crew's output, so it never becomes pointless. |
| **Crew** | Nine hireable tiers, from a Rusty Pick to a Magma Tap. Each purchase makes the next 13% dearer. Buy in x1 / x10 / MAX. |
| **Dig Deeper** | The gold sink. Each level multiplies *all* income by 1.25x and pushes you toward the next ore layer (Topsoil → Clay → Limestone → Granite → Obsidian → Magma → Crystal → The Void). Cost climbs 1.9x a level, so it stays a real decision. |
| **Detonate** | Prestige. Once you have earned 100M in a run, blow the shaft: lose the gold, the crew and the depth, keep gems. Each gem is +2% income, forever. |
| **Idle** | The crew keeps working while the app is closed, at 50% rate, capped at 12 hours. You are met with a "while you were away" card on your next launch. |

## Controls

| Input | Action |
| --- | --- |
| Tap anywhere | Swing the pick |
| Tap the **CREW** pill | Open the shop |
| START | Swing (mine screen) / quick-buy the best crew you can afford (shop) |
| Swipe up | Crew |
| Swipe down | Dig Deeper |
| Swipe left | Detonate |
| MENU (long-press up) | Hub menu: Crew, Dig Deeper, Detonate, Stats, Options |
| BACK | Leave the current screen |

Options holds a haptics toggle and a confirmation-guarded save wipe.

## Layout

```
source/
  DeepShaftApp.mc     AppBase; owns the GameState and hands out getInitialView()
  GameState.mc        The whole simulation: rates, costs, prestige, save/load
  Balance.mc          Every tuning constant, isolated so the curve can be re-balanced
  Fmt.mc              Large-number formatting (1.24M, 8.42Qa) and durations
  Names.mc            Resource lookups for the index-addressed name tables
  Theme.mc            Palette and shared drawing primitives
  Haptics.mc          Vibration, guarded for products without Attention
  GameView.mc         Base view: frame timer, ticks the simulation, requests redraws
  MineView.mc         Home screen: gold, rate, strata, the digger and its ore chips
  CrewView.mc         The shop
  DigView.mc          Depth purchases
  DetonateView.mc     Prestige, with a shockwave animation
  WelcomeView.mc      "While you were away"
  StatsView.mc        Run and lifetime totals
  MainMenu.mc         Hub menu, options menu, and the shared push helpers
  *Delegate.mc        Input handling, one per screen
```

The simulation is advanced from wall-clock time (`System.getTimer()`), not from
frame counts, so income does not depend on how often the active view happens to
redraw. Only the visible view runs a timer. Offline progress is reconstructed
from a saved UTC timestamp on load.

Nothing uses layout XML: every screen is drawn against `dc.getWidth()` /
`dc.getHeight()` in percentages, and text is inset using the chord width of the
round display at that height, so the same code fits the 416x416 Venu 2 and Venu
2 Plus and the 360x360 Venu 2S.

## Building

Requires the Connect IQ SDK and a developer key.

```sh
monkeyc -f monkey.jungle -o bin/DeepShaft.prg -d venu2 -y /path/to/developer_key.der -w -l 3
```

`-l 3` is the strict type checker; the project builds clean at that level for
`venu2`, `venu2s` and `venu2plus`. To sideload, copy the `.prg` to
`GARMIN/APPS/` on the watch, or run it in the Connect IQ simulator with
`monkeydo bin/DeepShaft.prg venu2`.

Minimum API level is 3.2.0, which every Venu 2 firmware satisfies. The app
requests no permissions.

## Balance

The pacing was checked with an offline simulation of a greedy player. On a first
run, the nine crew tiers unlock at roughly 0, 5, 24, 41, 55, 68, 80, 90 and 98
minutes, and the first prestige becomes available at about 66 minutes of active
play — sooner in practice, since offline earnings feed into it.

Prestige payout is deliberately **logarithmic**
(`20 * log10(runEarned / 10M)`). Idle income compounds twice over — more crew
*and* a deeper shaft — so a power-law payout runs away: an early draft handed
out 160,000 gems for a four-hour session. The log curve still rewards a longer
run (188 gems at four hours, 212 at twelve) but with sharp diminishing returns,
so every prestige matters instead of only the last one.
