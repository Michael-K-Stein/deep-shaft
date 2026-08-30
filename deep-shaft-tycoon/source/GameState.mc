import Toybox.Lang;
import Toybox.Application;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;

//! The whole simulation: eight mine shafts, each hauling ore on a timer.
//!
//! A shaft is either idle (waiting for a tap) or hauling. When a haul finishes
//! the cash lands; a shaft with a manager immediately starts the next haul,
//! which is what turns the game from a tapper into an idler.
class GameState {

    // Currencies
    var cash as Double = 0.0d;             // spendable
    var lifetime as Double = 0.0d;         // every dollar ever earned (drives prestige)
    var runEarned as Double = 0.0d;        // earned since the last sell-off
    var bars as Number = 0;                // gold bars held (permanent +2% each)
    var barsGranted as Number = 0;         // bars handed out so far

    // Per-shaft state
    var level as Array<Number> = [1, 0, 0, 0, 0, 0, 0, 0];   // 0 = still sealed
    var manager as Array<Boolean> = [false, false, false, false, false, false, false, false];
    var progress as Array<Number> = [-1, -1, -1, -1, -1, -1, -1, -1];  // ms into the haul, -1 = idle

    // Session / meta
    var buyMode as Number = 0;             // 0 = x1, 1 = x10, 2 = max
    var boostMs as Number = 0;             // remaining boost time
    var cooldownMs as Number = 0;          // remaining boost cooldown
    var taps as Number = 0;                // lifetime hauls started by hand
    var hauls as Number = 0;               // lifetime hauls delivered
    var sellOffs as Number = 0;            // prestige count
    var lastEpoch as Number = 0;           // unix seconds at last save

    //! Text for the "while you were away" card, or null.
    var welcomeText as String? = null;

    function initialize() {
        reset(true);
        lastEpoch = Time.now().value();
    }

    //! Wipe progress. `hard` also clears prestige currency and statistics.
    function reset(hard as Boolean) as Void {
        cash = 0.0d;
        runEarned = 0.0d;
        level = [1, 0, 0, 0, 0, 0, 0, 0];
        manager = [false, false, false, false, false, false, false, false];
        progress = [-1, -1, -1, -1, -1, -1, -1, -1];
        boostMs = 0;
        cooldownMs = 0;
        if (hard) {
            lifetime = 0.0d;
            bars = 0;
            barsGranted = 0;
            buyMode = 0;
            taps = 0;
            hauls = 0;
            sellOffs = 0;
            welcomeText = null;
        }
    }

    // ---------------------------------------------------------------- income

    //! Permanent bar bonus, times the boost if it is running.
    function multiplier() as Double {
        var m = 1.0d + Balance.BAR_BONUS * bars;
        if (boostMs > 0) {
            m *= Balance.BOOST_MULT;
        }
        return m;
    }

    //! Income per second from managed shafts only - hand-tapped shafts are not
    //! predictable, so they are deliberately left out of the headline rate.
    function incomePerSecond() as Double {
        var mult = multiplier();
        var total = 0.0d;
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (level[i] > 0 && manager[i]) {
                var secs = Balance.cycleMs(i, level[i]) / 1000.0d;
                total += (Balance.haulValue(i, level[i]) * mult) / secs;
            }
        }
        return total;
    }

    function award(amount as Double) as Void {
        cash += amount;
        lifetime += amount;
        runEarned += amount;
    }

    // ------------------------------------------------------------- simulation

    //! Advance every running shaft by `dtMs` milliseconds.
    function update(dtMs as Number) as Void {
        if (dtMs <= 0) {
            return;
        }
        if (boostMs > 0) {
            boostMs -= dtMs;
            if (boostMs < 0) {
                boostMs = 0;
            }
        }
        if (cooldownMs > 0) {
            cooldownMs -= dtMs;
            if (cooldownMs < 0) {
                cooldownMs = 0;
            }
        }

        var mult = multiplier();
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (level[i] <= 0 || progress[i] < 0) {
                continue;
            }
            progress[i] += dtMs;
            var cyc = Balance.cycleMs(i, level[i]);
            var value = Balance.haulValue(i, level[i]) * mult;
            // Bounded, so a long stretch in a menu cannot stall the UI.
            var guard = 0;
            while (progress[i] >= cyc && guard < 256) {
                award(value);
                hauls++;
                guard++;
                if (manager[i]) {
                    progress[i] -= cyc;
                } else {
                    progress[i] = -1;
                    break;
                }
            }
            if (guard >= 256 && progress[i] > cyc) {
                progress[i] = 0;
            }
        }
    }

    //! Fraction of the current haul completed, 0.0 - 1.0.
    function haulFraction(i as Number) as Double {
        if (level[i] <= 0 || progress[i] < 0) {
            return 0.0d;
        }
        var cyc = Balance.cycleMs(i, level[i]);
        var f = progress[i].toDouble() / cyc.toDouble();
        return f > 1.0d ? 1.0d : f;
    }

    // ----------------------------------------------------------------- actions

    //! Tap the body of a shaft: open it if sealed, otherwise send out a haul.
    //! Returns a short message for the status line, or null if nothing happened.
    function workShaft(i as Number) as String? {
        if (level[i] <= 0) {
            return buyUpgrade(i);
        }
        if (progress[i] >= 0) {
            return null;
        }
        progress[i] = 0;
        taps++;
        return null;
    }

    //! How many levels the current buy mode would purchase right now.
    function pendingLevels(i as Number) as Number {
        if (level[i] >= Balance.MAX_LEVEL) {
            return 0;
        }
        if (level[i] < 1) {
            // Buying a sealed shaft always means the single "open it" purchase.
            return 1;
        }
        var limit = 1;
        if (buyMode == 1) {
            limit = 10;
        } else if (buyMode == 2) {
            limit = Balance.MAX_LEVEL;
        }
        var n = Balance.affordableLevels(i, level[i], cash, limit);
        // Unaffordable buttons still show a price, so the player knows what
        // they are saving up for. Buy-max falls back to the next single level.
        if (n <= 0) {
            return (buyMode == 2) ? 1 : limit;
        }
        return n;
    }

    //! Buy levels according to the buy mode. Returns a status message or null.
    function buyUpgrade(i as Number) as String? {
        if (level[i] >= Balance.MAX_LEVEL) {
            return "Fully dug out";
        }
        var n = pendingLevels(i);
        if (n <= 0) {
            return "Not enough cash";
        }
        var cost = Balance.bulkCost(i, level[i], n);
        if (cost > cash) {
            return "Not enough cash";
        }
        var wasSealed = level[i] < 1;
        cash -= cost;
        level[i] += n;
        if (level[i] > Balance.MAX_LEVEL) {
            level[i] = Balance.MAX_LEVEL;
        }
        if (wasSealed) {
            return Balance.NAMES[i] + " opened!";
        }
        var ms = Balance.nextMilestone(level[i] - n);
        if (ms != null && level[i] >= ms) {
            return "Lvl " + ms.format("%d") + ": crew twice as fast!";
        }
        return null;
    }

    function canHire(i as Number) as Boolean {
        return level[i] > 0 && !manager[i] && cash >= Balance.MANAGER[i];
    }

    //! Put a manager on a shaft so it hauls forever without you.
    function hireManager(i as Number) as String? {
        if (level[i] <= 0) {
            return "Open the shaft first";
        }
        if (manager[i]) {
            return null;
        }
        if (cash < Balance.MANAGER[i]) {
            return "Manager: " + Fmt.money(Balance.MANAGER[i]);
        }
        cash -= Balance.MANAGER[i];
        manager[i] = true;
        if (progress[i] < 0) {
            progress[i] = 0;
        }
        return "Manager hired - it runs itself";
    }

    function boostReady() as Boolean {
        return boostMs <= 0 && cooldownMs <= 0;
    }

    //! The free 2x. No ad, no store page, no "close button" hunt.
    function startBoost() as String? {
        if (!boostReady()) {
            return null;
        }
        boostMs = Balance.BOOST_MS;
        cooldownMs = Balance.BOOST_COOLDOWN_MS + Balance.BOOST_MS;
        return "Crew rallied - double haul!";
    }

    //! Bars that a sell-off would hand over right now.
    function pendingBars() as Number {
        var n = Balance.barsEarned(lifetime) - barsGranted;
        return n > 0 ? n : 0;
    }

    //! Prestige: sell the mine, keep the bars, start again richer.
    function sellMine() as Boolean {
        var gain = pendingBars();
        if (gain <= 0) {
            return false;
        }
        bars += gain;
        barsGranted += gain;
        sellOffs++;
        reset(false);
        return true;
    }

    function hireAllManagers() as Number {
        var hired = 0;
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (canHire(i)) {
                hireManager(i);
                hired++;
            }
        }
        return hired;
    }

    // -------------------------------------------------------- offline earnings

    //! Pay out for time spent away, capped and at a reduced rate. Sets
    //! `welcomeText` when there is something worth reporting.
    function applyOffline(elapsedSec as Number) as Void {
        welcomeText = null;
        if (elapsedSec <= 0) {
            return;
        }
        var sec = elapsedSec;
        var capped = false;
        if (sec > Balance.OFFLINE_CAP_SEC) {
            sec = Balance.OFFLINE_CAP_SEC;
            capped = true;
        }
        // Boost never runs while away. The cooldown is burned down in Double
        // space, because a long absence overflows a 32-bit millisecond count.
        boostMs = 0;
        var awayMs = elapsedSec.toDouble() * 1000.0d;
        if (awayMs >= cooldownMs.toDouble()) {
            cooldownMs = 0;
        } else {
            cooldownMs -= awayMs.toNumber();
        }

        var mult = 1.0d + Balance.BAR_BONUS * bars;
        var gained = 0.0d;
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (level[i] <= 0) {
                continue;
            }
            if (manager[i]) {
                var cyc = Balance.cycleMs(i, level[i]).toDouble();
                var cycles = (sec.toDouble() * 1000.0d) / cyc;
                gained += cycles * Balance.haulValue(i, level[i]) * mult * Balance.OFFLINE_RATE;
                progress[i] = 0;
            } else if (progress[i] >= 0) {
                // The haul that was in flight when you left still lands.
                gained += Balance.haulValue(i, level[i]) * mult;
                hauls++;
                progress[i] = -1;
            }
        }
        if (gained <= 0.0d) {
            return;
        }
        award(gained);
        var line = "The crew kept digging for " + Fmt.duration(sec);
        if (capped) {
            line = "Crew ran the full " + Fmt.duration(Balance.OFFLINE_CAP_SEC) + " shift";
        }
        welcomeText = line + "|" + Fmt.money(gained);
    }

    // -------------------------------------------------------------- persistence

    const SAVE_KEY = "deepshaft.v1";

    function save() as Void {
        lastEpoch = Time.now().value();
        var data = {
            "v" => 1,
            "cash" => cash,
            "life" => lifetime,
            "run" => runEarned,
            "bars" => bars,
            "granted" => barsGranted,
            "lvl" => level,
            "mgr" => manager,
            "prog" => progress,
            "buy" => buyMode,
            "cool" => cooldownMs,
            "taps" => taps,
            "hauls" => hauls,
            "sells" => sellOffs,
            "t" => lastEpoch
        };
        try {
            Application.Storage.setValue(SAVE_KEY, data);
        } catch (ex) {
            // A full storage partition must never take the game down.
            System.println("save failed");
        }
    }

    //! Restore a save if there is one, then pay out offline earnings.
    function load() as Void {
        var data = null;
        try {
            data = Application.Storage.getValue(SAVE_KEY);
        } catch (ex) {
            data = null;
        }
        if (!(data instanceof Dictionary)) {
            lastEpoch = Time.now().value();
            return;
        }

        cash = num(data["cash"], 0.0d).toDouble();
        lifetime = num(data["life"], 0.0d).toDouble();
        runEarned = num(data["run"], 0.0d).toDouble();
        bars = num(data["bars"], 0).toNumber();
        barsGranted = num(data["granted"], 0).toNumber();
        buyMode = num(data["buy"], 0).toNumber();
        cooldownMs = num(data["cool"], 0).toNumber();
        taps = num(data["taps"], 0).toNumber();
        hauls = num(data["hauls"], 0).toNumber();
        sellOffs = num(data["sells"], 0).toNumber();

        readLevels(data["lvl"]);
        readFlags(data["mgr"]);
        readProgress(data["prog"]);

        if (buyMode < 0 || buyMode > 2) {
            buyMode = 0;
        }
        if (bars < 0) { bars = 0; }
        if (barsGranted < bars) { barsGranted = bars; }

        var saved = num(data["t"], 0).toNumber();
        var now = Time.now().value();
        lastEpoch = now;
        if (saved > 0 && now > saved) {
            applyOffline(now - saved);
        }

        // A managed shaft is never idle, whatever the save said.
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (level[i] > 0 && manager[i] && progress[i] < 0) {
                progress[i] = 0;
            }
        }
    }

    //! Read a number out of a save, tolerating older or corrupted saves.
    hidden function num(raw as Object?, fallback as Numeric) as Numeric {
        if (raw instanceof Number || raw instanceof Float ||
            raw instanceof Long || raw instanceof Double) {
            return raw;
        }
        return fallback;
    }

    hidden function readLevels(raw as Object?) as Void {
        if (!(raw instanceof Array)) {
            return;
        }
        for (var i = 0; i < Balance.SHAFT_COUNT && i < raw.size(); i++) {
            var v = raw[i];
            if (v instanceof Number) {
                level[i] = v < 0 ? 0 : (v > Balance.MAX_LEVEL ? Balance.MAX_LEVEL : v);
            }
        }
    }

    hidden function readFlags(raw as Object?) as Void {
        if (!(raw instanceof Array)) {
            return;
        }
        for (var i = 0; i < Balance.SHAFT_COUNT && i < raw.size(); i++) {
            var v = raw[i];
            manager[i] = (v instanceof Boolean) ? v : false;
        }
    }

    hidden function readProgress(raw as Object?) as Void {
        if (!(raw instanceof Array)) {
            return;
        }
        for (var i = 0; i < Balance.SHAFT_COUNT && i < raw.size(); i++) {
            var v = raw[i];
            if (v instanceof Number) {
                progress[i] = v < 0 ? -1 : v;
            }
        }
    }
}
