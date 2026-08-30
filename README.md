# Idle Games for Garmin

Idle games for Connect IQ watches. One directory per game.

| Game | Watches | What it is |
| --- | --- | --- |
| [`deep-shaft-pit/`](deep-shaft-pit/) | Venu 2, Venu 2 Plus, Venu 2S | Swing a pick at an animated rock face, hire nine crew types, dig deeper through eight strata, then detonate the mine for gems. |

```sh
cd deep-shaft-pit
tools/build.sh --fetch-sdk
```

The build needs only `java` and Python. It generates the device configurations
from the SDK's own device table, so the graphical SDK Manager is not required.
If you already have an SDK installed:

```sh
CIQ_SDK="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-..." tools/build.sh
```

That produces `build/venu2.prg`, `build/venu2s.prg` and `build/venu2plus.prg`.
Copy the `.prg` into `GARMIN/APPS/` on a watch plugged in over USB.

See the game's own README for its mechanics, controls and tooling.

## A retired sibling

A second game, **Deep Shaft Tycoon**, lived in `deep-shaft-tycoon/` until it was
retired. It was a scrolling list of eight shafts, each with its own haul timer,
upgrade price and manager badge - the AdVenture-Capitalist shape, where this one
is the clicker shape. It played badly on the watch: the list was too dense to
read at a glance and too fiddly to navigate on a 416px round screen.

Its tooling was the better half of it, and that survives here:
`tools/simulate_economy.py` and `tools/check_layout.py` were both written for
the tycoon first and then rebuilt against this game's formulas and screens.

The code is still in the history if it is ever wanted:

```sh
git show 39d79a1:deep-shaft-tycoon/README.md
git checkout 39d79a1 -- deep-shaft-tycoon      # to bring it back
```
