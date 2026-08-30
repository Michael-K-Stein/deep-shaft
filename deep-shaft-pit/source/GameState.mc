import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

//! The whole simulation. Views never mutate these fields directly; they call
//! the buy/dig/detonate helpers so the invariants stay in one place.
class GameState {

    //! Bumped whenever the save layout changes incompatibly.
    private const SAVE_VERSION = 1;
    private const SAVE_KEY = "deepshaft";

    // --- Persistent state ------------------------------------------------
    public var gold as Double = 0.0d;
    public var crew as Array<Number>;
    public var depthLevel as Number = 0;
    public var gems as Number = 0;
    public var runEarned as Double = 0.0d;
    public var lifetimeEarned as Double = 0.0d;
    public var swings as Number = 0;
    public var detonations as Number = 0;
    public var playedSecs as Number = 0;
    public var haptics as Boolean = true;
    public var lastSeen as Number = 0;

    // --- Transient state -------------------------------------------------
    //! Gold banked while the app was closed, waiting to be collected.
    public var offlineGain as Double = 0.0d;
    public var offlineSecs as Number = 0;

    private var mLastTickMs as Number = 0;
    private var mFractionSecs as Float = 0.0;
    private var mSinceSaveSecs as Float = 0.0;

    function initialize() {
        crew = new [Balance.CREW_COUNT] as Array<Number>;
        for (var i = 0; i < Balance.CREW_COUNT; i += 1) {
            crew[i] = 0;
        }
        mLastTickMs = System.getTimer();
    }

    // ---------------------------------------------------------------- rates

    //! Gold per second before any multipliers.
    function baseRate() as Double {
        var total = 0.0d;
        for (var i = 0; i < Balance.CREW_COUNT; i += 1) {
            var owned = crew[i] as Number;
            if (owned > 0) {
                total += (Balance.CREW_BASE_RATE as Array<Double>)[i] * owned;
            }
        }
        return total;
    }

    //! Depth bonus times gem bonus. Applies to idle income and to swings.
    function multiplier() as Double {
        var depth = Math.pow(Balance.DEPTH_BONUS, depthLevel).toDouble();
        var gem = 1.0d + Balance.GEM_BONUS * gems;
        return depth * gem;
    }

    function ratePerSecond() as Double {
        return baseRate() * multiplier();
    }

    //! What one manual swing is worth right now.
    function swingValue() as Double {
        return (Balance.TAP_BASE + baseRate() * Balance.TAP_RATE_SHARE) * multiplier();
    }

    // ----------------------------------------------------------------- crew

    //! Price of the next unit of a crew type after `alreadyOwned` purchases.
    function crewCost(index as Number, alreadyOwned as Number) as Double {
        var base = (Balance.CREW_BASE_COST as Array<Double>)[index];
        return base * Math.pow(Balance.COST_GROWTH, alreadyOwned).toDouble();
    }

    //! Price of buying `count` more units in one go (a geometric series).
    function crewBundleCost(index as Number, count as Number) as Double {
        if (count <= 0) {
            return 0.0d;
        }
        var r = Balance.COST_GROWTH;
        var first = crewCost(index, crew[index] as Number);
        var ratio = Math.pow(r, count).toDouble();
        return first * (ratio - 1.0d) / (r - 1.0d);
    }

    //! Largest bundle the player can currently afford, capped so a single tap
    //! can never buy a silly number of units.
    function crewMaxAffordable(index as Number) as Number {
        var first = crewCost(index, crew[index] as Number);
        if (gold < first) {
            return 0;
        }
        var r = Balance.COST_GROWTH;
        var ratio = gold * (r - 1.0d) / first + 1.0d;
        var n = (Math.log(ratio, r)).toNumber();
        if (n < 1) {
            n = 1;
        }
        if (n > 999) {
            n = 999;
        }
        // Rounding in log() can overshoot by one; walk back until it fits.
        while (n > 1 && crewBundleCost(index, n) > gold) {
            n -= 1;
        }
        return n;
    }

    //! Buy up to `count` units. Returns how many were actually bought.
    function buyCrew(index as Number, count as Number) as Number {
        var want = count;
        if (want <= 0) {
            return 0;
        }
        var affordable = crewMaxAffordable(index);
        if (affordable < want) {
            want = affordable;
        }
        if (want <= 0) {
            return 0;
        }
        var price = crewBundleCost(index, want);
        if (price > gold) {
            return 0;
        }
        gold -= price;
        crew[index] = (crew[index] as Number) + want;
        return want;
    }

    //! Crew types stay hidden until they are within reach, so the shop grows
    //! with the player instead of dumping nine rows on them at once.
    function crewRevealed(index as Number) as Boolean {
        if (index == 0) {
            return true;
        }
        if ((crew[index] as Number) > 0) {
            return true;
        }
        if ((crew[index - 1] as Number) > 0) {
            return true;
        }
        var base = (Balance.CREW_BASE_COST as Array<Double>)[index];
        return lifetimeEarned >= base * Balance.REVEAL_FRACTION;
    }

    //! Number of crew rows currently worth showing.
    function revealedCount() as Number {
        var n = 1;
        for (var i = 1; i < Balance.CREW_COUNT; i += 1) {
            if (crewRevealed(i)) {
                n = i + 1;
            }
        }
        return n;
    }

    // ---------------------------------------------------------------- depth

    function depthCost() as Double {
        return Balance.DEPTH_BASE_COST
            * Math.pow(Balance.DEPTH_COST_GROWTH, depthLevel).toDouble();
    }

    function canDig() as Boolean {
        return gold >= depthCost();
    }

    function dig() as Boolean {
        var cost = depthCost();
        if (gold < cost) {
            return false;
        }
        gold -= cost;
        depthLevel += 1;
        return true;
    }

    function depthMetres() as Number {
        return depthLevel * Balance.METRES_PER_LEVEL;
    }

    function layerIndex() as Number {
        var idx = depthLevel / Balance.LEVELS_PER_LAYER;
        if (idx >= Balance.LAYER_COUNT) {
            idx = Balance.LAYER_COUNT - 1;
        }
        return idx;
    }

    //! 0.0 .. 1.0 progress toward affording the next depth level. Drives the
    //! ring around the main screen.
    function depthProgress() as Float {
        var cost = depthCost();
        if (cost <= 0.0d) {
            return 1.0;
        }
        var p = (gold / cost).toFloat();
        if (p < 0.0) {
            p = 0.0;
        }
        if (p > 1.0) {
            p = 1.0;
        }
        return p;
    }

    // ------------------------------------------------------------- prestige

    //! Gems the player would walk away with if they detonated right now.
    //! See Balance.DETONATE_SCALE for why this is logarithmic.
    function pendingGems() as Number {
        if (runEarned < Balance.DETONATE_MIN_EARNED) {
            return 0;
        }
        var ratio = runEarned / Balance.DETONATE_REFERENCE;
        var n = (Balance.DETONATE_SCALE * Math.log(ratio, 10.0d)).toNumber();
        return (n > 0) ? n : 1;
    }

    function canDetonate() as Boolean {
        return pendingGems() > 0;
    }

    //! Wipe the run, bank the gems. Lifetime stats and gems survive.
    function detonate() as Number {
        var earned = pendingGems();
        if (earned <= 0) {
            return 0;
        }
        gems += earned;
        detonations += 1;
        gold = 0.0d;
        runEarned = 0.0d;
        depthLevel = 0;
        for (var i = 0; i < Balance.CREW_COUNT; i += 1) {
            crew[i] = 0;
        }
        save();
        return earned;
    }

    function gemBonusPercent() as Number {
        return (Balance.GEM_BONUS * 100.0d * gems).toNumber();
    }

    // ----------------------------------------------------------------- loop

    //! Credit one manual swing.
    function swing() as Double {
        var value = swingValue();
        gold += value;
        runEarned += value;
        lifetimeEarned += value;
        swings += 1;
        return value;
    }

    //! Advance the simulation using wall-clock time, so the result does not
    //! depend on how often the active view happens to redraw.
    function tick() as Void {
        var now = System.getTimer();
        var dtMs = now - mLastTickMs;
        mLastTickMs = now;

        // System.getTimer() wraps roughly every 25 days; a negative or absurd
        // delta means we lost track, so charge nothing for it.
        if (dtMs < 0 || dtMs > 5000) {
            dtMs = 0;
        }
        if (dtMs == 0) {
            return;
        }

        var dt = dtMs / 1000.0;
        var earned = ratePerSecond() * dt;
        gold += earned;
        runEarned += earned;
        lifetimeEarned += earned;

        mFractionSecs += dt;
        while (mFractionSecs >= 1.0) {
            mFractionSecs -= 1.0;
            playedSecs += 1;
        }

        mSinceSaveSecs += dt;
        if (mSinceSaveSecs >= Balance.AUTOSAVE_SECS) {
            mSinceSaveSecs = 0.0;
            save();
        }
    }

    //! Move the pending offline pile into the wallet.
    function collectOffline() as Void {
        if (offlineGain > 0.0d) {
            gold += offlineGain;
            runEarned += offlineGain;
            lifetimeEarned += offlineGain;
        }
        offlineGain = 0.0d;
        offlineSecs = 0;
    }

    // ------------------------------------------------------------ persistence

    function save() as Void {
        lastSeen = Time.now().value();
        var data = {
            "v" => SAVE_VERSION,
            "gold" => gold,
            "crew" => crew,
            "depth" => depthLevel,
            "gems" => gems,
            "run" => runEarned,
            "life" => lifetimeEarned,
            "swings" => swings,
            "boom" => detonations,
            "played" => playedSecs,
            "haptics" => haptics,
            "seen" => lastSeen
        };
        Application.Storage.setValue(SAVE_KEY, data);
    }

    function load() as Void {
        mLastTickMs = System.getTimer();
        var raw = Application.Storage.getValue(SAVE_KEY);
        if (!(raw instanceof Lang.Dictionary)) {
            return;
        }
        var data = raw as Dictionary;
        if (readNumber(data, "v", 0) != SAVE_VERSION) {
            return;
        }

        gold = readDouble(data, "gold", 0.0d);
        depthLevel = readNumber(data, "depth", 0);
        gems = readNumber(data, "gems", 0);
        runEarned = readDouble(data, "run", 0.0d);
        lifetimeEarned = readDouble(data, "life", 0.0d);
        swings = readNumber(data, "swings", 0);
        detonations = readNumber(data, "boom", 0);
        playedSecs = readNumber(data, "played", 0);
        lastSeen = readNumber(data, "seen", 0);

        var flag = data["haptics"];
        haptics = (flag instanceof Lang.Boolean) ? flag : true;

        var saved = data["crew"];
        if (saved instanceof Lang.Array) {
            var list = saved as Array;
            for (var i = 0; i < Balance.CREW_COUNT && i < list.size(); i += 1) {
                var value = list[i];
                crew[i] = (value instanceof Lang.Number && value >= 0) ? value : 0;
            }
        }

        computeOffline();
    }

    //! Work out what the crew dug up while the app was closed.
    private function computeOffline() as Void {
        offlineGain = 0.0d;
        offlineSecs = 0;
        if (lastSeen <= 0) {
            return;
        }
        var elapsed = Time.now().value() - lastSeen;
        if (elapsed < Balance.MIN_OFFLINE_SECS) {
            return;
        }
        if (elapsed > Balance.MAX_OFFLINE_SECS) {
            elapsed = Balance.MAX_OFFLINE_SECS;
        }
        var gain = ratePerSecond() * elapsed * Balance.OFFLINE_EFFICIENCY;
        if (gain <= 0.0d) {
            return;
        }
        offlineSecs = elapsed;
        offlineGain = gain;
    }

    function wipe() as Void {
        gold = 0.0d;
        depthLevel = 0;
        gems = 0;
        runEarned = 0.0d;
        lifetimeEarned = 0.0d;
        swings = 0;
        detonations = 0;
        playedSecs = 0;
        offlineGain = 0.0d;
        offlineSecs = 0;
        for (var i = 0; i < Balance.CREW_COUNT; i += 1) {
            crew[i] = 0;
        }
        Application.Storage.deleteValue(SAVE_KEY);
        save();
    }

    // --------------------------------------------------------------- helpers

    private function readNumber(data as Dictionary, key as String, fallback as Number) as Number {
        var value = data[key];
        return (value instanceof Lang.Number) ? value : fallback;
    }

    private function readDouble(data as Dictionary, key as String, fallback as Double) as Double {
        var value = data[key];
        if (value instanceof Lang.Double || value instanceof Lang.Float
                || value instanceof Lang.Number || value instanceof Lang.Long) {
            var d = value.toDouble();
            return (d >= 0.0d) ? d : fallback;
        }
        return fallback;
    }
}
