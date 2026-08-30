#!/usr/bin/env python3
"""Check that the Python tools still agree with source/Balance.mc.

`simulate_economy.py` only tells the truth about the difficulty curve while its
copy of the tuning matches the game's. Nothing in the build enforces that, so a
balance change lands in one file and quietly invalidates the other. This parses
the constants out of both and compares them.

    python3 tools/check_constants.py
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Balance.mc name -> simulate_economy.py name. Scalars only; the two rate and
# cost tables are compared separately.
SCALARS = {
    "CREW_COUNT": "CREW_COUNT",
    "COST_GROWTH": "COST_GROWTH",
    "REVEAL_FRACTION": "REVEAL_FRACTION",
    "MILESTONE_EVERY": "MILESTONE_EVERY",
    "MILESTONE_MULT": "MILESTONE_MULT",
    "DEPTH_BASE_COST": "DEPTH_BASE_COST",
    "DEPTH_COST_GROWTH": "DEPTH_COST_GROWTH",
    "DEPTH_BONUS": "DEPTH_BONUS",
    "METRES_PER_LEVEL": "METRES_PER_LEVEL",
    "LAYER_COUNT": "LAYER_COUNT",
    "LEVELS_PER_LAYER": "LEVELS_PER_LAYER",
    "DETONATE_MIN_EARNED": "DETONATE_MIN_EARNED",
    "DETONATE_REFERENCE": "DETONATE_REFERENCE",
    "DETONATE_SCALE": "DETONATE_SCALE",
    "GEM_BONUS": "GEM_BONUS",
    "TAP_BASE": "TAP_BASE",
    "TAP_RATE_SHARE": "TAP_RATE_SHARE",
    "STRIKE_MIN_SECS": "STRIKE_MIN_SECS",
    "STRIKE_MAX_SECS": "STRIKE_MAX_SECS",
    "STRIKE_REWARD_SECS": "STRIKE_REWARD_SECS",
    "STRIKE_MIN_SWINGS": "STRIKE_MIN_SWINGS",
}

ARRAYS = {
    "CREW_BASE_COST": "CREW_BASE_COST",
    "CREW_BASE_RATE": "CREW_BASE_RATE",
}


def number(text):
    """Read a Monkey C or Python numeric literal. The `d` suffix marks a
    Monkey C Double and carries no meaning here."""
    return float(text.strip().rstrip("dDfF"))


def monkey_constants(path):
    src = io.open(path, encoding="utf-8").read()
    scalars, arrays = {}, {}
    for name, value in re.findall(
            r"const\s+(\w+)\s*=\s*(-?[\d.]+[dDfF]?)\s*;", src):
        scalars[name] = number(value)
    for name, body in re.findall(
            r"const\s+(\w+)\s*=\s*\[(.*?)\]\s*;", src, re.S):
        if name in ARRAYS:
            arrays[name] = [number(v) for v in body.split(",") if v.strip()]
    return scalars, arrays


def python_constants(path):
    src = io.open(path, encoding="utf-8").read()
    scalars, arrays = {}, {}
    for name, value in re.findall(r"^(\w+)\s*=\s*(-?[\d.]+)\s*$", src, re.M):
        scalars[name] = number(value)
    for name, body in re.findall(r"^(\w+)\s*=\s*\[(.*?)\]", src, re.M | re.S):
        if name in ARRAYS.values():
            arrays[name] = [number(v) for v in body.split(",") if v.strip()]
    return scalars, arrays


def main():
    mc = os.path.join(ROOT, "source", "Balance.mc")
    py = os.path.join(ROOT, "tools", "simulate_economy.py")
    mc_scalars, mc_arrays = monkey_constants(mc)
    py_scalars, py_arrays = python_constants(py)

    problems = []
    for mc_name, py_name in sorted(SCALARS.items()):
        if mc_name not in mc_scalars:
            problems.append("Balance.mc no longer defines %s" % mc_name)
            continue
        if py_name not in py_scalars:
            problems.append("simulate_economy.py is missing %s" % py_name)
            continue
        if mc_scalars[mc_name] != py_scalars[py_name]:
            problems.append("%s: Balance.mc has %g, simulate_economy.py has %g"
                            % (mc_name, mc_scalars[mc_name], py_scalars[py_name]))

    for mc_name, py_name in sorted(ARRAYS.items()):
        got, want = mc_arrays.get(mc_name), py_arrays.get(py_name)
        if got is None or want is None:
            problems.append("%s is missing from one of the two files" % mc_name)
        elif got != want:
            problems.append("%s differs:\n     Balance.mc %s\n     tools      %s"
                            % (mc_name, got, want))

    if problems:
        for problem in problems:
            print("   FAIL %s" % problem)
        print("\n   The simulation is only meaningful while these agree.")
        return 1

    print("   OK   %d constants and %d tables match source/Balance.mc"
          % (len(SCALARS), len(ARRAYS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
