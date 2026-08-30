#!/usr/bin/env python3
"""Play Deep Shaft Pit very fast, to check the difficulty curve.

This mirrors the formulas in `source/Balance.mc`. It drives a greedy player who
always buys whatever adds the most income per dollar - the next crew member or
the next depth level - and prints when each crew tier and each ore layer lands,
so the pacing can be checked without grinding it out on a watch.

    python3 tools/simulate_economy.py
    python3 tools/simulate_economy.py --hours 24 --taps 2
    python3 tools/simulate_economy.py --gems 200      # after a detonation

Keep this in step with source/Balance.mc: the constants below are a copy, and
the whole point of the script is that they match.
"""
import argparse
import math

# --- mirrored from source/Balance.mc ---------------------------------------
CREW_COUNT = 17
COST_GROWTH = 1.13
CREW_BASE_COST = [15.0, 130.0, 1500.0, 18000.0, 240000.0,
                  3600000.0, 60000000.0, 1100000000.0, 25000000000.0,
                  600000000000.0, 17000000000000.0, 520000000000000.0,
                  18000000000000000.0, 700000000000000000.0,
                  28000000000000000000.0, 1000000000000000000000.0,
                  36000000000000000000000.0]
CREW_BASE_RATE = [0.15, 1.2, 9.0, 70.0, 520.0,
                  4200.0, 38000.0, 380000.0, 4200000.0,
                  50000000.0, 650000000.0, 9100000000.0, 140000000000.0,
                  2300000000000.0, 40000000000000.0, 600000000000000.0,
                  9000000000000000.0]
REVEAL_FRACTION = 0.30

MILESTONE_EVERY = 25
MILESTONE_MULT = 2.0

DEPTH_BASE_COST = 400.0
DEPTH_COST_GROWTH = 1.9
DEPTH_BONUS = 1.25
METRES_PER_LEVEL = 12
LAYER_COUNT = 12
LEVELS_PER_LAYER = 6

DETONATE_MIN_EARNED = 100000000.0
DETONATE_REFERENCE = 10000000.0
DETONATE_SCALE = 20.0
GEM_BONUS = 0.02

TAP_BASE = 1.0
TAP_RATE_SHARE = 0.10

STRIKE_MIN_SECS = 75.0
STRIKE_MAX_SECS = 210.0
STRIKE_REWARD_SECS = 25.0
STRIKE_MIN_SWINGS = 12.0

CREW_NAMES = ["Rusty Pick", "Shovel Crew", "Ore Cart", "Drill Rig", "Blast Team",
              "Excavator", "Laser Bore", "Quantum Auger", "Magma Tap",
              "Plasma Lance", "Gravity Well", "Rift Engine", "Star Forge",
              "Quasar Drive", "Singularity Core", "Galactic Maw",
              "Aeon Engine"]
LAYER_NAMES = ["Topsoil", "Clay", "Limestone", "Granite",
               "Obsidian", "Magma", "Crystal", "Neutronium",
               "Antimatter", "Singularity", "Genesis", "The Void"]


def crew_cost(index, owned):
    return CREW_BASE_COST[index] * (COST_GROWTH ** owned)


def depth_cost(depth_level):
    return DEPTH_BASE_COST * (DEPTH_COST_GROWTH ** depth_level)


def milestone_mult(owned):
    """Every MILESTONE_EVERY units of a type doubles that type's output."""
    return MILESTONE_MULT ** (owned // MILESTONE_EVERY)


def base_rate(crew):
    return sum(CREW_BASE_RATE[i] * crew[i] * milestone_mult(crew[i])
               for i in range(CREW_COUNT))


def multiplier(depth_level, gems):
    return (DEPTH_BONUS ** depth_level) * (1.0 + GEM_BONUS * gems)


def crew_revealed(index, crew, run_earned):
    """Mirror of GameState.crewRevealed - the shop only shows what is in reach.

    Keyed on the current run, not lifetime earnings, so a detonation folds the
    shop back down to the tiers the fresh run can actually reach."""
    if index == 0 or crew[index] > 0 or crew[index - 1] > 0:
        return True
    return run_earned >= CREW_BASE_COST[index] * REVEAL_FRACTION


def pending_gems(run_earned):
    if run_earned < DETONATE_MIN_EARNED:
        return 0
    n = int(DETONATE_SCALE * math.log10(run_earned / DETONATE_REFERENCE))
    return n if n > 0 else 1


def fmt_money(v):
    for suffix in ("", "K", "M", "B", "T", "q", "Q", "s", "S"):
        if abs(v) < 1000:
            return ("%.2f%s" if abs(v) < 10 else "%.0f%s") % (v, suffix)
        v /= 1000.0
    return "%.1fY" % v


def fmt_time(seconds):
    seconds = int(seconds)
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm %02ds" % (seconds // 60, seconds % 60)
    if seconds < 86400:
        return "%dh %02dm" % (seconds // 3600, (seconds % 3600) // 60)
    return "%dd %02dh" % (seconds // 86400, (seconds % 86400) // 3600)


def simulate(hours, gems, taps_per_second, step=1.0):
    crew = [0] * CREW_COUNT
    depth_level = 0
    gold = 0.0
    run_earned = 0.0
    lifetime = 0.0
    events = []
    seen_crew = set()
    seen_layer = {0}
    detonate_at = None

    for tick in range(int(hours * 3600 / step)):
        now = tick * step

        mult = multiplier(depth_level, gems)
        earned = base_rate(crew) * mult * step
        if taps_per_second > 0.0:
            swing = (TAP_BASE + base_rate(crew) * TAP_RATE_SHARE) * mult
            earned += swing * taps_per_second * step
            # A player who is tapping is watching, so assume they take the
            # veins too. Averaged over the mean interval rather than modelled
            # as discrete events - the point here is the curve, not the noise.
            reward = max(base_rate(crew) * mult * STRIKE_REWARD_SECS,
                         swing * STRIKE_MIN_SWINGS)
            earned += reward / ((STRIKE_MIN_SECS + STRIKE_MAX_SECS) / 2.0) * step
        gold += earned
        run_earned += earned
        lifetime += earned

        # Greedy purchasing: whatever buys the most income per dollar.
        progressed = True
        while progressed:
            progressed = False
            mult = multiplier(depth_level, gems)
            rate_now = base_rate(crew)

            best_kind, best_index, best_ratio = None, -1, 0.0

            for i in range(CREW_COUNT):
                if not crew_revealed(i, crew, run_earned):
                    continue
                cost = crew_cost(i, crew[i])
                if cost > gold:
                    continue
                # The unit itself, plus the doubling if it happens to be the
                # one that trips a milestone - which is what makes stacking a
                # single crew type worth doing.
                before = CREW_BASE_RATE[i] * crew[i] * milestone_mult(crew[i])
                after = CREW_BASE_RATE[i] * (crew[i] + 1) * milestone_mult(crew[i] + 1)
                gain = (after - before) * mult
                ratio = gain / cost
                if ratio > best_ratio:
                    best_kind, best_index, best_ratio = "crew", i, ratio

            cost = depth_cost(depth_level)
            if cost <= gold and rate_now > 0.0:
                # A depth level multiplies everything the crew already produces.
                gain = rate_now * mult * (DEPTH_BONUS - 1.0)
                ratio = gain / cost
                if ratio > best_ratio:
                    best_kind, best_index, best_ratio = "depth", -1, ratio

            if best_kind == "crew":
                gold -= crew_cost(best_index, crew[best_index])
                crew[best_index] += 1
                if best_index not in seen_crew:
                    seen_crew.add(best_index)
                    events.append((now, "hired first %s" % CREW_NAMES[best_index]))
                progressed = True
            elif best_kind == "depth":
                gold -= depth_cost(depth_level)
                depth_level += 1
                layer = min(depth_level // LEVELS_PER_LAYER, LAYER_COUNT - 1)
                if layer not in seen_layer:
                    seen_layer.add(layer)
                    events.append((now, "reached %s (%dm down)"
                                   % (LAYER_NAMES[layer], depth_level * METRES_PER_LEVEL)))
                progressed = True

        if detonate_at is None and run_earned >= DETONATE_MIN_EARNED:
            detonate_at = now
            events.append((now, "detonation unlocked (%d gems)" % pending_gems(run_earned)))

    return crew, depth_level, gold, run_earned, lifetime, events


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--hours", type=float, default=2.0,
                    help="hours of play to simulate (default 2)")
    ap.add_argument("--gems", type=int, default=0,
                    help="gems carried in from a previous detonation")
    ap.add_argument("--taps", type=float, default=0.0, metavar="PER_SEC",
                    help="manual swings per second; 0 (default) models pure idling")
    ap.add_argument("--step", type=float, default=1.0,
                    help="simulation step in seconds (default 1)")
    args = ap.parse_args()

    crew, depth_level, gold, run_earned, lifetime, events = simulate(
        args.hours, args.gems, args.taps, args.step)

    mode = "idle only" if args.taps <= 0.0 else "%.3g taps/s" % args.taps
    print("Deep Shaft Pit - %g hours, %s, %d gems carried in\n"
          % (args.hours, mode, args.gems))
    for when, what in events:
        print("  %8s  %s" % (fmt_time(when), what))
    if not events:
        print("  nothing happened - a fresh mine earns nothing without taps.")
        print("  Try --taps 1 to model someone actually playing.")

    mult = multiplier(depth_level, args.gems)
    layer = min(depth_level // LEVELS_PER_LAYER, LAYER_COUNT - 1)
    print("\n  final gold      %s" % fmt_money(gold))
    print("  run earned      %s" % fmt_money(run_earned))
    print("  income/s        %s" % fmt_money(base_rate(crew) * mult))
    print("  depth           level %d, %dm, %s"
          % (depth_level, depth_level * METRES_PER_LEVEL, LAYER_NAMES[layer]))
    print("  gems on offer   %d" % pending_gems(run_earned))
    print("  crew            %s" % " ".join("%d" % c for c in crew))
    print("  milestones      %s"
          % " ".join("%d" % (c // MILESTONE_EVERY) for c in crew))


if __name__ == "__main__":
    main()
