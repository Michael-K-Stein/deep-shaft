# Idle Games for Garmin

Idle games for Connect IQ watches. One directory per game.

Two takes on the same idea live here. They started as independent designs and
both were worth keeping, so both build, both install, and they sit side by side
on the watch with different launcher icons.

| Game | Watches | What it is |
| --- | --- | --- |
| [`deep-shaft-tycoon/`](deep-shaft-tycoon/) | Venu 2, Venu 2 Plus, Venu 2S | A shaft-list tycoon: eight shafts, managers that run them for you, offline earnings, and a prestige sell-off. Ore-cart icon. |
| [`deep-shaft-pit/`](deep-shaft-pit/) | Venu 2, Venu 2 Plus, Venu 2S | An animated rock face: swing a pick, hire nine crew types, dig deeper through eight strata, then detonate the mine for gems. Pickaxe icon. |

**Deep Shaft Tycoon** is the AdVenture-Capitalist shape — a scrolling list of
shafts, each with its own haul timer, upgrade price and manager badge. The
screen is dense with numbers and every row is a decision.

**Deep Shaft (pit)** is the clicker shape — one animated screen with a miner
swinging a pick at drifting rock strata, gold counting up, ore chips flying,
and the shop behind a menu. The screen is mostly picture and the numbers stay
out of the way.

Each game builds on its own:

```sh
cd deep-shaft-tycoon      # or deep-shaft-pit
tools/build.sh --fetch-sdk
```

Both build scripts take the same options and need only `java` and Python. They
generate the device configurations from the SDK's own device table, so the
graphical SDK Manager is not required. If you already have an SDK installed:

```sh
CIQ_SDK="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-..." tools/build.sh
```

That produces `build/venu2.prg`, `build/venu2s.prg` and `build/venu2plus.prg`.
Copy the `.prg` into `GARMIN/APPS/` on a watch plugged in over USB.

See each game's own README for its mechanics, controls and tooling.
