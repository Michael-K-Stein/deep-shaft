# Deep Shaft Tycoon

An idle mining tycoon for the **Garmin Venu 2**, written in Monkey C for
Connect IQ.

It is built on the genre those idle-game ads are cut from — the ones with the
shafts, the little miners hauling ore up to a cart, the manager you hire so it
runs itself, and the "YOUR MINE EARNED $4.2M WHILE YOU WERE AWAY" card when you
come back. All of it fits on a 416px round watch face, and none of it asks you
to watch an ad.

```
              $1.24M
           +$8.4K/s  22 bars

   ╭────────────────────────────────╮
   │ (M)  Copper Seam        L42    │
   │      $18.4K / 1.3s      ┌────┐ │
   │      ▓▓▓▓▓▓▓▓░░░░░░░░   │ +10│ │
   ╰─────────────────────────│$96K│─╯
   ╭─────────────────────────└────┘─╮
   │ (T)  Iron Gallery       L12    │
   ...

      [ 2x FREE ] [ BUY x1 ] [ MENU ]
```

## The loop

Eight shafts, each deeper and richer than the last.

- **Work a shaft** — tap it and the crew goes down. When the haul lands, you get
  paid. Early on you are tapping constantly; that is the point.
- **Upgrade it** — tap the price button. Every level raises what one haul is
  worth, and each level costs 7% more than the last.
- **Hire a manager** — tap the shaft's badge. The shaft then hauls forever
  without you. This is the purchase that turns the game from a tapper into an
  idler, so it is priced accordingly, at thirty times what the shaft cost to
  open.
- **Milestones** — levels 25, 50, 100 and 200 halve a shaft's haul time. Passing
  one doubles that shaft's income outright.
- **The free 2x** — the ad-game staple, minus the ad. Doubles all income for 30
  seconds on a 5 minute cooldown.
- **Come back later** — managed shafts keep hauling while you are away, at 60%
  rate for up to 8 hours, and the payout is waiting on a card when you return.
- **Sell the mine** — once you have earned $1B in all, you can sell up. Shafts
  and cash reset; you keep gold bars worth **+2% income each, forever**. Bars
  are granted on lifetime earnings (`20 × √(lifetime / $1B)`), so every mine you
  sell is worth more than the last.

Roughly: the second shaft opens within a minute, all eight are running inside
two hours, and the first sell-off is worth taking at around the one hour mark.
Those numbers come out of `tools/simulate_economy.py`, which plays the game
against the real formulas — see below.

## Controls

Venu 2 has a touchscreen and two buttons, and every action has both.

| Action | Touch | Button |
| --- | --- | --- |
| Work a shaft | tap the middle of its row | START sends every idle crew down |
| Upgrade | tap the price button on the right | — |
| Hire a manager | tap the round badge on the left | — |
| Free 2x boost | tap `2x FREE` | START (when it is off cooldown) |
| Change buy amount (×1 / ×10 / max) | tap `BUY …` | in the menu |
| Mine office menu | tap `MENU` | hold START |
| Scroll the shaft list | swipe up / down | — |
| Leave | swipe right | BACK |

A green pip on a badge means you can afford that manager right now. The badge
ring fills as the haul runs — gold if a manager is running it, blue if you are.

The mine office holds the buy amount, bulk manager hiring, the sell-off,
statistics, and a how-to-play page.

## Building

You need `java` and `python3`. You do **not** need the graphical SDK Manager:
device configurations are generated from the device table inside the SDK itself.

```sh
tools/build.sh --fetch-sdk      # downloads the SDK into build/, then builds
tools/build.sh                  # subsequent builds
tools/build.sh venu2            # a single device
CIQ_SDK=~/connectiq-sdk tools/build.sh    # use an SDK you already have
```

That produces `build/venu2.prg`, `build/venu2s.prg` and
`build/venu2plus.prg`, compiled with the type checker at its strictest setting
(`--typecheck 3 --warn`, clean). The same script runs in CI on every push.

To put it on a watch, plug the Venu 2 in over USB and copy the `.prg` into
`GARMIN/APPS/` on the device, then find it in the app list. The build script
generates a throwaway signing key on first run; if you intend to publish to the
Connect IQ store, point `CIQ_KEY` at the key you registered instead.

## Layout

```
manifest.xml                 app id, product list, permissions (none)
monkey.jungle                build config
source/
  DeepShaftApp.mc            app entry point
  Balance.mc                 every tuning number and formula
  GameState.mc               the simulation: hauls, purchases, offline, saves
  Fmt.mc                     big-number and duration formatting
  MineView.mc                the mine screen, laid out from the display size
  MineDelegate.mc            touch and button handling
  Menus.mc                   mine office, confirmations, text pages
resources/                   strings
resources-round-416x416/     70px launcher icon (Venu 2, Venu 2 Plus)
resources-round-360x360/     61px launcher icon (Venu 2S)
tools/
  build.sh                   fetch the SDK, generate devices, build
  make_device_json.py        device configs from the SDK's device table
  make_icon.py               draws the ore-cart launcher icon at any size
  check_layout.py            asserts the UI fits inside the round display
  simulate_economy.py        plays the game fast, to check the difficulty curve
```

## Tuning it

Everything that decides how the game feels is in `source/Balance.mc`: unlock
costs, haul values, cycle times, manager prices, milestone levels, the boost,
the offline cap, and the prestige formula. Change a number there and re-run

```sh
python3 tools/simulate_economy.py --hours 6
python3 tools/simulate_economy.py --hours 8 --idle --managed 2   # nobody tapping
python3 tools/simulate_economy.py --hours 6 --bars 200           # after a sell-off
```

to see where the milestones land before flashing it to a watch. The Python
mirrors the Monkey C formulas exactly, so keep the two in step when you edit
either.

`tools/check_layout.py` does the same job for the screen: it reproduces
`MineView.onLayout` and asserts that every panel, badge and button still fits
inside the circle on both 416px and 360px displays. It already caught the action
bar clipping the bezel by half a pixel on the Venu 2S.
