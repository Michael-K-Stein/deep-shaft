import Toybox.Lang;
import Toybox.Math;

//! All of the game's tuning lives here, so the economy can be re-balanced
//! without touching game logic or rendering.
//!
//! The curve follows the shape every "idle mining tycoon" ad promises:
//! each shaft costs ~12x the previous one but pays ~9x more per haul, so a new
//! shaft is always a big jump that then slowly gets out-earned by upgrading the
//! ones you already own.
module Balance {

    const SHAFT_COUNT = 8;
    const MAX_LEVEL = 400;

    //! Cost growth per level. 1.07 is the classic idle-game ratio: cheap at
    //! first, and eventually the reason you prestige.
    const UPGRADE_RATE = 1.07d;

    //! Levels at which the crew works twice as fast (halved haul time).
    const MILESTONE_1 = 25;
    const MILESTONE_2 = 50;
    const MILESTONE_3 = 100;
    const MILESTONE_4 = 200;

    const MIN_CYCLE_MS = 240;

    //! Prestige: gold bars granted for lifetime earnings, and what each is worth.
    //! $1B lifetime is roughly an hour of active play, by which point most of
    //! the mine is open - so the first sell-off is a real decision, not a
    //! reflex a few minutes in.
    const BAR_SCALE = 20.0d;         // bars = BAR_SCALE * sqrt(lifetime / BAR_BASE)
    const BAR_BASE = 1000000000.0d;
    const BAR_BONUS = 0.02d;         // +2% global income per bar

    //! "Rally the crew" boost - the game's wink at every "watch an ad for 2x!"
    //! banner, except it is free and on a timer instead.
    const BOOST_MS = 30000;
    const BOOST_COOLDOWN_MS = 300000;
    const BOOST_MULT = 2.0d;

    //! Offline earnings. Managed shafts keep hauling while the watch is on your
    //! wrist doing anything else, at a reduced rate and with a hard cap.
    const OFFLINE_CAP_SEC = 8 * 3600;
    const OFFLINE_RATE = 0.6d;

    var NAMES as Array<String> = [
        "Surface Cut",
        "Copper Seam",
        "Iron Gallery",
        "Silver Drift",
        "Gold Reef",
        "Ruby Hollow",
        "Cobalt Abyss",
        "Meteor Core"
    ];

    //! Depth label shown on each shaft badge, purely for flavour.
    var DEPTHS as Array<String> = ["20m", "80m", "210m", "540m", "1.2k", "2.6k", "5.5k", "9.9k"];

    //! Cost to open the shaft (which also puts it at level 1).
    var UNLOCK as Array<Double> = [
        4.0d, 48.0d, 576.0d, 6912.0d,
        82944.0d, 995328.0d, 11943936.0d, 143327232.0d
    ];

    //! Cash delivered by one full haul at level 1, before any multipliers.
    var HAUL as Array<Double> = [
        1.0d, 9.0d, 81.0d, 729.0d,
        6561.0d, 59049.0d, 531441.0d, 4782969.0d
    ];

    //! Base duration of one haul, in milliseconds. Deeper shafts are slower but
    //! pay far more, so the early game is tappy and the late game is idle.
    var CYCLE_MS as Array<Number> = [1000, 2600, 4200, 5800, 7400, 9000, 10600, 12200];

    //! A manager runs the shaft for you forever. This is the single most
    //! important purchase in the genre, so it is priced at 30 unlocks.
    var MANAGER as Array<Double> = [
        120.0d, 1440.0d, 17280.0d, 207360.0d,
        2488320.0d, 29859840.0d, 358318080.0d, 4299816960.0d
    ];

    //! Total cost of buying `count` levels starting from `level`
    //! (a geometric series, so buy-max stays cheap to evaluate).
    function bulkCost(idx as Number, level as Number, count as Number) as Double {
        if (count <= 0) {
            return 0.0d;
        }
        if (level < 1) {
            // The first "level" is the unlock itself, priced separately.
            var rest = bulkCost(idx, 1, count - 1);
            return UNLOCK[idx] + rest;
        }
        var first = UNLOCK[idx] * Math.pow(UPGRADE_RATE, level - 1);
        var ratio = Math.pow(UPGRADE_RATE, count);
        return first * (ratio - 1.0d) / (UPGRADE_RATE - 1.0d);
    }

    //! How many levels `cash` can buy for a shaft already at `level`.
    function affordableLevels(idx as Number, level as Number, cash as Double, limit as Number) as Number {
        if (level < 1) {
            return cash >= UNLOCK[idx] ? 1 : 0;
        }
        var head = UNLOCK[idx] * Math.pow(UPGRADE_RATE, level - 1);
        if (cash < head) {
            return 0;
        }
        // Invert the geometric series: n = log(1 + cash*(r-1)/head) / log(r)
        var inner = 1.0d + (cash * (UPGRADE_RATE - 1.0d)) / head;
        var n = (Math.log(inner, UPGRADE_RATE)).toNumber();
        if (n < 1) {
            n = 1;
        }
        if (n > limit) {
            n = limit;
        }
        if (level + n > MAX_LEVEL) {
            n = MAX_LEVEL - level;
        }
        // Guard against floating point optimism at the boundary.
        while (n > 1 && bulkCost(idx, level, n) > cash) {
            n--;
        }
        return n;
    }

    //! Haul duration for a shaft, after milestone speed-ups.
    function cycleMs(idx as Number, level as Number) as Number {
        var speed = 1;
        if (level >= MILESTONE_1) { speed *= 2; }
        if (level >= MILESTONE_2) { speed *= 2; }
        if (level >= MILESTONE_3) { speed *= 2; }
        if (level >= MILESTONE_4) { speed *= 2; }
        var ms = CYCLE_MS[idx] / speed;
        return ms < MIN_CYCLE_MS ? MIN_CYCLE_MS : ms;
    }

    //! The next level that will speed this shaft up, or null once maxed out.
    function nextMilestone(level as Number) as Number? {
        if (level < MILESTONE_1) { return MILESTONE_1; }
        if (level < MILESTONE_2) { return MILESTONE_2; }
        if (level < MILESTONE_3) { return MILESTONE_3; }
        if (level < MILESTONE_4) { return MILESTONE_4; }
        return null;
    }

    //! Cash delivered by one haul, before global multipliers.
    function haulValue(idx as Number, level as Number) as Double {
        return HAUL[idx] * level;
    }

    //! Gold bars a player with this lifetime total has earned in all.
    function barsEarned(lifetime as Double) as Number {
        if (lifetime < BAR_BASE) {
            return 0;
        }
        return (BAR_SCALE * Math.sqrt(lifetime / BAR_BASE)).toNumber();
    }
}
