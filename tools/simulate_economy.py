#!/usr/bin/env python3
"""Play Deep Shaft Tycoon very fast, to check the difficulty curve.

This mirrors the formulas in `source/Balance.mc`. It drives a greedy player
(hire managers first, then open the deepest shaft it can afford, then buy the
upgrade with the best payback) and prints when each milestone lands, so the
pacing can be checked without grinding it on a watch.

    python3 tools/simulate_economy.py
    python3 tools/simulate_economy.py --hours 48 --idle
"""
import argparse
import math

SHAFT_COUNT = 8
MAX_LEVEL = 400
UPGRADE_RATE = 1.07
MILESTONES = (25, 50, 100, 200)
MIN_CYCLE_MS = 240
BAR_SCALE = 20.0
BAR_BASE = 1_000_000_000.0
BAR_BONUS = 0.02

NAMES = ["Surface Cut", "Copper Seam", "Iron Gallery", "Silver Drift",
         "Gold Reef", "Ruby Hollow", "Cobalt Abyss", "Meteor Core"]
UNLOCK = [4.0, 48.0, 576.0, 6912.0, 82944.0, 995328.0, 11943936.0, 143327232.0]
HAUL = [1.0, 9.0, 81.0, 729.0, 6561.0, 59049.0, 531441.0, 4782969.0]
CYCLE_MS = [1000, 2600, 4200, 5800, 7400, 9000, 10600, 12200]
MANAGER = [120.0, 1440.0, 17280.0, 207360.0,
           2488320.0, 29859840.0, 358318080.0, 4299816960.0]


def cycle_ms(idx, level):
    speed = 1
    for milestone in MILESTONES:
        if level >= milestone:
            speed *= 2
    return max(MIN_CYCLE_MS, CYCLE_MS[idx] // speed)


def upgrade_cost(idx, level):
    return UNLOCK[idx] * (UPGRADE_RATE ** (level - 1))


def haul_value(idx, level):
    return HAUL[idx] * level


def income_per_second(level, manager, multiplier, idle_only):
    """Cash per second. `idle_only` counts managed shafts only, as the watch does."""
    total = 0.0
    for i in range(SHAFT_COUNT):
        if level[i] <= 0:
            continue
        if idle_only and not manager[i]:
            continue
        total += haul_value(i, level[i]) * multiplier / (cycle_ms(i, level[i]) / 1000.0)
    return total


def fmt_money(v):
    for suffix in ("", "K", "M", "B", "T", "q", "Q", "s", "S"):
        if abs(v) < 1000:
            return "$%.2f%s" % (v, suffix) if abs(v) < 10 else "$%.0f%s" % (v, suffix)
        v /= 1000.0
    return "$%.1fY" % v


def fmt_time(seconds):
    seconds = int(seconds)
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm %02ds" % (seconds // 60, seconds % 60)
    if seconds < 86400:
        return "%dh %02dm" % (seconds // 3600, (seconds % 3600) // 60)
    return "%dd %02dh" % (seconds // 86400, (seconds % 86400) // 3600)


def simulate(hours, idle_only, bars, managed=0):
    level = [1] + [0] * (SHAFT_COUNT - 1)
    manager = [False] * SHAFT_COUNT
    for i in range(min(managed, SHAFT_COUNT)):
        level[i] = max(level[i], 1)
        manager[i] = True
    cash = 0.0
    lifetime = 0.0
    multiplier = 1.0 + BAR_BONUS * bars
    events = []
    step = 1.0

    for tick in range(int(hours * 3600 / step)):
        now = tick * step
        earned = income_per_second(level, manager, multiplier, idle_only) * step
        cash += earned
        lifetime += earned

        # Greedy purchasing, cheapest useful thing first.
        progressed = True
        while progressed:
            progressed = False

            for i in range(SHAFT_COUNT):
                if level[i] > 0 and not manager[i] and cash >= MANAGER[i]:
                    cash -= MANAGER[i]
                    manager[i] = True
                    events.append((now, "manager on %s" % NAMES[i]))
                    progressed = True

            for i in reversed(range(SHAFT_COUNT)):
                if level[i] == 0 and cash >= UNLOCK[i]:
                    cash -= UNLOCK[i]
                    level[i] = 1
                    events.append((now, "opened %s" % NAMES[i]))
                    progressed = True
                    break

            # Best payback: extra income per dollar spent.
            best, best_ratio = -1, 0.0
            for i in range(SHAFT_COUNT):
                if level[i] <= 0 or level[i] >= MAX_LEVEL:
                    continue
                cost = upgrade_cost(i, level[i])
                if cost > cash:
                    continue
                before = haul_value(i, level[i]) / (cycle_ms(i, level[i]) / 1000.0)
                after = haul_value(i, level[i] + 1) / (cycle_ms(i, level[i] + 1) / 1000.0)
                ratio = (after - before) / cost
                if ratio > best_ratio:
                    best, best_ratio = i, ratio
            if best >= 0:
                cost = upgrade_cost(best, level[best])
                cash -= cost
                level[best] += 1
                if level[best] in MILESTONES:
                    events.append((now, "%s hit level %d (2x speed)"
                                   % (NAMES[best], level[best])))
                progressed = True

        if lifetime >= BAR_BASE and not any("first sell-off" in e[1] for e in events):
            events.append((now, "first sell-off available"))

    return level, manager, cash, lifetime, events


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--hours", type=float, default=12.0, help="hours of play to simulate")
    ap.add_argument("--bars", type=int, default=0, help="gold bars carried in from a previous mine")
    ap.add_argument("--idle", action="store_true",
                    help="count managed shafts only (pure idling, nobody tapping)")
    ap.add_argument("--managed", type=int, default=0, metavar="N",
                    help="start with the first N shafts already open and staffed, "
                         "to model idling into an established mine")
    args = ap.parse_args()

    level, manager, cash, lifetime, events = simulate(
        args.hours, args.idle, args.bars, args.managed)

    mode = "idle only" if args.idle else "actively tapping"
    print("Deep Shaft Tycoon - %g hours, %s, %d bars carried in\n"
          % (args.hours, mode, args.bars))
    for when, what in events:
        print("  %8s  %s" % (fmt_time(when), what))
    if args.idle and lifetime == 0.0:
        print("  nothing happened: a fresh mine has no managers, and only managed")
        print("  shafts haul on their own. Try --managed 2 to idle into a going")
        print("  concern, or drop --idle to model someone actually playing.")

    multiplier = 1.0 + BAR_BONUS * args.bars
    print("\n  final cash      %s" % fmt_money(cash))
    print("  lifetime        %s" % fmt_money(lifetime))
    print("  income/s        %s" % fmt_money(
        income_per_second(level, manager, multiplier, True)))
    print("  bars on sale    %d" % int(BAR_SCALE * math.sqrt(lifetime / BAR_BASE))
          if lifetime >= BAR_BASE else "  bars on sale    0")
    print("  levels          %s" % " ".join("%d" % v for v in level))
    print("  managers        %s" % " ".join("Y" if m else "-" for m in manager))


if __name__ == "__main__":
    main()
