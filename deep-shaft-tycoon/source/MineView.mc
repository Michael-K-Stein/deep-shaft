import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;

//! The mine: a scrolling column of shafts with a cash header and an action bar.
//! Everything is laid out from the display size, so the same code fills a
//! 416x416 Venu 2 and a 360x360 Venu 2S.
class MineView extends WatchUi.View {

    // Palette. Dark ground for the AMOLED panel, gold for anything you own.
    const COL_BG       = 0x000000;
    const COL_PANEL    = 0x1B1E28;
    const COL_SEALED   = 0x0E1016;
    const COL_TEXT     = 0xFFFFFF;
    const COL_DIM      = 0x9AA0AE;
    const COL_FAINT    = 0x555C6B;
    const COL_GOLD     = 0xFFAA00;
    const COL_GOLD_DK  = 0x5A3D00;
    const COL_CASH     = 0x55E06E;
    const COL_STEEL    = 0x5A6377;
    const COL_BLUE     = 0x33AAFF;

    const VISIBLE = 3;
    const FLASH_MS = 320;
    const TOAST_MS = 2200;
    const AUTOSAVE_MS = 20000;

    //! Most time this view is hidden is a menu or a dialog, and the crew should
    //! keep working through it. Anything longer than this is treated as the
    //! watch having parked the app, and is left to the offline payout on load.
    const CATCHUP_MS = 300000;

    var state as GameState;
    var scrollIdx as Number;

    // Layout, filled in by onLayout.
    var w as Number = 0;
    var h as Number = 0;
    var cx as Number = 0;
    var cy as Number = 0;
    var rowX as Number = 0;
    var rowW as Number = 0;
    var rowTop as Number = 0;
    var rowH as Number = 0;
    var rowGap as Number = 0;
    var badgeR as Number = 0;
    var btnW as Number = 0;
    var barY as Number = 0;
    var barH as Number = 0;
    var actW as Number = 0;
    var actGap as Number = 0;
    var actX as Number = 0;

    hidden var timer as Timer.Timer?;
    hidden var lastTick as Number = 0;
    hidden var sinceSave as Number;
    hidden var prevProgress as Array<Number>;
    hidden var flash as Array<Number>;
    hidden var toast as String?;
    hidden var toastMs as Number;

    function initialize(gameState as GameState) {
        View.initialize();
        state = gameState;
        scrollIdx = 0;
        sinceSave = 0;
        toast = null;
        toastMs = 0;
        prevProgress = [0, 0, 0, 0, 0, 0, 0, 0];
        flash = [0, 0, 0, 0, 0, 0, 0, 0];
    }

    function onLayout(dc as Graphics.Dc) as Void {
        w = dc.getWidth();
        h = dc.getHeight();
        cx = w / 2;
        cy = h / 2;

        rowX = w * 85 / 1000;
        rowW = w - 2 * rowX;
        rowTop = h * 255 / 1000;
        rowH = h * 154 / 1000;
        rowGap = h * 15 / 1000;
        badgeR = rowH * 38 / 100;
        btnW = rowW * 24 / 100;

        barH = h * 100 / 1000;
        barY = h * 780 / 1000;
        actW = w * 180 / 1000;
        actGap = w * 22 / 1000;
        actX = cx - (3 * actW + 2 * actGap) / 2;
    }

    function onShow() as Void {
        if (lastTick == 0) {
            // First show only. On the way back from a menu the old timestamp is
            // kept on purpose, so the hauls that finished meanwhile still pay.
            lastTick = System.getTimer();
        }
        if (timer == null) {
            timer = new Timer.Timer();
        }
        timer.start(method(:onTick), 50, true);
    }

    function onHide() as Void {
        if (timer != null) {
            timer.stop();
        }
        state.save();
    }

    //! Drive the simulation off wall-clock deltas, so time spent in a menu or
    //! on a confirmation dialog still counts as digging time.
    function onTick() as Void {
        var now = System.getTimer();
        var dt = now - lastTick;
        lastTick = now;
        if (dt < 0) {
            // System.getTimer() wrapped around; skip this frame's worth.
            dt = 50;
        } else if (dt > CATCHUP_MS) {
            dt = CATCHUP_MS;
        }

        state.update(dt);

        if (toastMs > 0) {
            toastMs -= dt;
            if (toastMs <= 0) {
                toast = null;
            }
        }
        for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
            if (flash[i] > 0) {
                flash[i] -= dt;
            }
            // A haul landed when the progress counter fell back.
            if (state.progress[i] < prevProgress[i]) {
                flash[i] = FLASH_MS;
            }
            prevProgress[i] = state.progress[i];
        }

        sinceSave += dt;
        if (sinceSave >= AUTOSAVE_MS) {
            sinceSave = 0;
            state.save();
        }
        WatchUi.requestUpdate();
    }

    //! Show a short message in place of the income line.
    function say(message as String?) as Void {
        if (message == null) {
            return;
        }
        toast = message;
        toastMs = TOAST_MS;
        WatchUi.requestUpdate();
    }

    function scrollBy(delta as Number) as Void {
        var maxIdx = Balance.SHAFT_COUNT - VISIBLE;
        scrollIdx += delta;
        if (scrollIdx < 0) {
            scrollIdx = 0;
        }
        if (scrollIdx > maxIdx) {
            scrollIdx = maxIdx;
        }
        WatchUi.requestUpdate();
    }

    // -------------------------------------------------------------- rendering

    function onUpdate(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(COL_TEXT, COL_BG);
        dc.clear();

        drawHeader(dc);
        for (var slot = 0; slot < VISIBLE; slot++) {
            drawShaft(dc, scrollIdx + slot, rowTop + slot * (rowH + rowGap));
        }
        drawScrollbar(dc);
        drawActionBar(dc);

        var welcome = state.welcomeText;
        if (welcome != null) {
            drawWelcome(dc, welcome);
        }
    }

    hidden function drawHeader(dc as Graphics.Dc) as Void {
        var boosted = state.boostMs > 0;
        dc.setColor(boosted ? COL_GOLD : COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 60 / 1000, Graphics.FONT_LARGE,
                    Fmt.money(state.cash), Graphics.TEXT_JUSTIFY_CENTER);

        var line;
        var colour;
        if (toast != null) {
            line = toast;
            colour = COL_GOLD;
        } else {
            line = "+" + Fmt.rate(state.incomePerSecond());
            colour = COL_CASH;
            if (state.bars > 0) {
                line = line + "  " + state.bars.format("%d") + " bars";
            }
        }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 175 / 1000, Graphics.FONT_XTINY, line,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShaft(dc as Graphics.Dc, idx as Number, y as Number) as Void {
        if (idx < 0 || idx >= Balance.SHAFT_COUNT) {
            return;
        }
        var sealed = state.level[idx] <= 0;
        var lit = flash[idx] > 0;

        dc.setColor(sealed ? COL_SEALED : (lit ? 0x2A2F3D : COL_PANEL),
                    Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, y, rowW, rowH, 10);

        drawBadge(dc, idx, rowX + badgeR + 6, y + rowH / 2, sealed);

        var textX = rowX + 2 * badgeR + 16;
        var textW = rowW - (textX - rowX) - btnW - 10;
        var titleY = y + rowH * 30 / 100;
        var subY = y + rowH * 62 / 100;

        // Title line: shaft name, plus its level on the right.
        dc.setColor(sealed ? COL_FAINT : COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, titleY, Graphics.FONT_XTINY, Balance.NAMES[idx],
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!sealed) {
            dc.setColor(COL_FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX + textW, titleY, Graphics.FONT_XTINY,
                        "L" + state.level[idx].format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Sub line: what one haul is worth, and how long it takes.
        var sub;
        if (sealed) {
            sub = "Sealed - " + Balance.DEPTHS[idx] + " down";
        } else {
            var value = Balance.haulValue(idx, state.level[idx]) * state.multiplier();
            var secs = Balance.cycleMs(idx, state.level[idx]) / 1000.0d;
            sub = Fmt.money(value) + " / " + secs.format("%.1f") + "s";
        }
        dc.setColor(sealed ? COL_FAINT : COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, subY, Graphics.FONT_XTINY, sub,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!sealed) {
            drawHaulBar(dc, idx, textX, y + rowH - 11, textW);
        }
        drawBuyButton(dc, idx, y, sealed);
    }

    //! Badge: a ring that fills as the haul runs, with the manager state inside.
    hidden function drawBadge(dc as Graphics.Dc, idx as Number, bx as Number, by as Number, sealed as Boolean) as Void {
        dc.setColor(sealed ? 0x171A22 : 0x11141B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, badgeR);

        dc.setPenWidth(3);
        dc.setColor(sealed ? COL_FAINT : (state.manager[idx] ? COL_GOLD_DK : COL_STEEL),
                    Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(bx, by, badgeR - 1);

        if (!sealed) {
            var frac = state.haulFraction(idx);
            if (frac > 0.0d) {
                var sweep = (frac * 360.0d).toNumber();
                if (sweep > 359) {
                    sweep = 359;
                }
                dc.setColor(state.manager[idx] ? COL_GOLD : COL_BLUE,
                            Graphics.COLOR_TRANSPARENT);
                dc.drawArc(bx, by, badgeR - 1, Graphics.ARC_CLOCKWISE, 90, deg(90 - sweep));
            }
        }
        dc.setPenWidth(1);

        var glyph;
        var colour;
        if (sealed) {
            glyph = "?";
            colour = COL_FAINT;
        } else if (state.manager[idx]) {
            glyph = "M";
            colour = COL_GOLD;
        } else {
            glyph = (idx + 1).format("%d");
            colour = COL_STEEL;
        }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx, by, Graphics.FONT_XTINY, glyph,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // A green pip means "you can afford this manager right now".
        if (state.canHire(idx)) {
            dc.setColor(COL_CASH, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx + badgeR - 4, by - badgeR + 4, 4);
        }
    }

    hidden function drawHaulBar(dc as Graphics.Dc, idx as Number, x as Number, y as Number, barW as Number) as Void {
        dc.setColor(0x2C313D, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, barW, 5, 2);

        var frac = state.haulFraction(idx);
        if (frac <= 0.0d) {
            return;
        }
        var fill = (barW * frac).toNumber();
        if (fill < 4) {
            fill = 4;
        }
        dc.setColor(state.manager[idx] ? COL_GOLD : COL_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, fill, 5, 2);
    }

    hidden function drawBuyButton(dc as Graphics.Dc, idx as Number, y as Number, sealed as Boolean) as Void {
        var bx = rowX + rowW - btnW - 6;
        var by = y + 8;
        var bh = rowH - 16;

        // One evaluation per frame: the buy-max price is a geometric series and
        // a search, so it is not something to compute twice per row.
        var levels = state.pendingLevels(idx);
        var cost = (levels > 0) ? Balance.bulkCost(idx, state.level[idx], levels) : null;
        var affordable = (cost != null) && (cost <= state.cash);

        dc.setColor(affordable ? 0x18301D : 0x22252E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, btnW, bh, 8);
        dc.setPenWidth(2);
        dc.setColor(affordable ? COL_CASH : COL_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, btnW, bh, 8);
        dc.setPenWidth(1);

        var label;
        if (cost == null) {
            label = "MAX";
        } else if (sealed) {
            label = "OPEN";
        } else {
            label = "+" + levels.format("%d");
        }

        dc.setColor(affordable ? COL_CASH : COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + btnW / 2, by + bh * 30 / 100, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (cost != null) {
            dc.setColor(affordable ? COL_TEXT : COL_FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + btnW / 2, by + bh * 72 / 100, Graphics.FONT_XTINY,
                        Fmt.money(cost),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Garmin-style scroll indicator hugging the right bezel.
    hidden function drawScrollbar(dc as Graphics.Dc) as Void {
        var total = Balance.SHAFT_COUNT;
        var maxIdx = total - VISIBLE;
        if (maxIdx <= 0) {
            return;
        }
        var radius = cx - 4;
        var span = 70;
        var thumb = span * VISIBLE / total;
        var offset = (span - thumb) * scrollIdx / maxIdx;

        dc.setPenWidth(4);
        dc.setColor(0x272B36, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, span / 2, 360 - span / 2);
        dc.setColor(COL_GOLD, Graphics.COLOR_TRANSPARENT);
        var start = span / 2 - offset;
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, deg(start), deg(start - thumb));
        dc.setPenWidth(1);
    }

    //! Wrap an angle into the 0-359 range drawArc expects.
    hidden function deg(angle as Number) as Number {
        var a = angle % 360;
        return a < 0 ? a + 360 : a;
    }

    //! Three touch targets: the free 2x, the buy-amount toggle, the menu.
    hidden function drawActionBar(dc as Graphics.Dc) as Void {
        var boostLabel;
        var boostColour;
        if (state.boostMs > 0) {
            boostLabel = "2x " + Fmt.duration(state.boostMs / 1000);
            boostColour = COL_GOLD;
        } else if (state.cooldownMs > 0) {
            boostLabel = Fmt.duration(state.cooldownMs / 1000);
            boostColour = COL_FAINT;
        } else {
            boostLabel = "2x FREE";
            boostColour = COL_CASH;
        }
        drawAction(dc, 0, boostLabel, boostColour);
        drawAction(dc, 1, buyModeLabel(), COL_BLUE);
        drawAction(dc, 2, "MENU", COL_DIM);
    }

    function buyModeLabel() as String {
        if (state.buyMode == 1) {
            return "BUY x10";
        }
        if (state.buyMode == 2) {
            return "BUY MAX";
        }
        return "BUY x1";
    }

    hidden function drawAction(dc as Graphics.Dc, slot as Number, label as String, colour as Number) as Void {
        var x = actX + slot * (actW + actGap);
        dc.setColor(0x171A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, barY, actW, barH, 8);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + actW / 2, barY + barH / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! "While you were away" card - the genre's signature reward screen.
    hidden function drawWelcome(dc as Graphics.Dc, text as String) as Void {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var panelX = w * 10 / 100;
        var panelW = w - 2 * panelX;
        var panelY = h * 26 / 100;
        var panelH = h * 48 / 100;

        dc.setColor(0x161A23, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(panelX, panelY, panelW, panelH, 16);
        dc.setPenWidth(3);
        dc.setColor(COL_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(panelX, panelY, panelW, panelH, 16);
        dc.setPenWidth(1);

        // The card text is "message|amount", so the payout can be given its
        // own oversized line.
        var detail = text;
        var amount = "";
        var split = findSplit(text);
        if (split >= 0) {
            var head = text.substring(0, split);
            var tail = text.substring(split + 1, text.length());
            detail = (head != null) ? head : text;
            amount = (tail != null) ? tail : "";
        }

        dc.setColor(COL_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, panelY + panelH * 18 / 100, Graphics.FONT_XTINY, "WELCOME BACK",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, panelY + panelH * 42 / 100, Graphics.FONT_XTINY, detail,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(COL_CASH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, panelY + panelH * 68 / 100, Graphics.FONT_MEDIUM, amount,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(COL_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, panelY + panelH + h * 6 / 100, Graphics.FONT_XTINY,
                    "tap to collect",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Index of the '|' separating the welcome message from its amount.
    hidden function findSplit(text as String) as Number {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == '|') {
                return i;
            }
        }
        return -1;
    }

    // ------------------------------------------------------------ hit testing

    //! Which shaft row a screen point falls in, or -1.
    function rowAt(x as Number, y as Number) as Number {
        if (x < rowX || x > rowX + rowW) {
            return -1;
        }
        for (var slot = 0; slot < VISIBLE; slot++) {
            var top = rowTop + slot * (rowH + rowGap);
            if (y >= top && y <= top + rowH) {
                var idx = scrollIdx + slot;
                return idx < Balance.SHAFT_COUNT ? idx : -1;
            }
        }
        return -1;
    }

    //! Which part of a row was hit: :badge, :buy or :body.
    function zoneAt(x as Number) as Symbol {
        if (x <= rowX + 2 * badgeR + 8) {
            return :badge;
        }
        if (x >= rowX + rowW - btnW - 10) {
            return :buy;
        }
        return :body;
    }

    //! Which action-bar button was hit (0-2), or -1.
    function actionAt(x as Number, y as Number) as Number {
        if (y < barY - 6 || y > barY + barH + 6) {
            return -1;
        }
        for (var i = 0; i < 3; i++) {
            var bx = actX + i * (actW + actGap);
            if (x >= bx - 4 && x <= bx + actW + 4) {
                return i;
            }
        }
        return -1;
    }
}
