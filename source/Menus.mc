import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

//! The mine office: buy amount, bulk manager hiring, prestige, stats, help.
class OfficeDelegate extends WatchUi.Menu2InputDelegate {

    hidden var state as GameState;
    hidden var view as MineView;

    function initialize(gameState as GameState, mineView as MineView) {
        Menu2InputDelegate.initialize();
        state = gameState;
        view = mineView;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :buymode) {
            state.buyMode = (state.buyMode + 1) % 3;
            item.setSubLabel(view.buyModeLabel());
            WatchUi.requestUpdate();

        } else if (id == :managers) {
            var hired = state.hireAllManagers();
            item.setSubLabel(hired > 0
                ? hired.format("%d") + " hired"
                : "Nothing affordable");
            WatchUi.requestUpdate();

        } else if (id == :sell) {
            var pending = state.pendingBars();
            if (pending <= 0) {
                item.setSubLabel("Not worth selling yet");
                WatchUi.requestUpdate();
            } else {
                var prompt = "Sell the mine for " + pending.format("%d") +
                             " gold bars?\nShafts and cash reset.";
                WatchUi.pushView(new WatchUi.Confirmation(prompt),
                                 new SellDelegate(state, item),
                                 WatchUi.SLIDE_UP);
            }

        } else if (id == :stats) {
            WatchUi.pushView(new PageView("STATISTICS", statLines()),
                             new PageDelegate(), WatchUi.SLIDE_LEFT);

        } else if (id == :help) {
            WatchUi.pushView(new PageView("HOW TO PLAY", helpLines()),
                             new PageDelegate(), WatchUi.SLIDE_LEFT);

        } else if (id == :wipe) {
            WatchUi.pushView(new WatchUi.Confirmation("Erase all progress?"),
                             new WipeDelegate(state), WatchUi.SLIDE_UP);
        }
    }

    hidden function statLines() as Array<Array<String> > {
        var bonus = (Balance.BAR_BONUS * state.bars * 100.0d);
        return [
            ["Earned all time", Fmt.money(state.lifetime)],
            ["This mine", Fmt.money(state.runEarned)],
            ["Gold bars", state.bars.format("%d") + "  (+" + bonus.format("%.0f") + "%)"],
            ["Mines sold", state.sellOffs.format("%d")],
            ["Hauls delivered", Fmt.big(state.hauls)],
            ["Hand-worked", Fmt.big(state.taps)],
            ["Income", Fmt.rate(state.incomePerSecond())]
        ];
    }

    //! Single-element rows render as centred lines of prose.
    hidden function helpLines() as Array<Array<String> > {
        return [
            ["Tap a shaft to work it."],
            ["Tap the price to upgrade."],
            ["Tap the badge to hire a"],
            ["manager. It hauls forever."],
            ["Lv 25/50/100 = 2x speed."],
            ["2x FREE doubles income"],
            ["for 30s. No ads, ever."],
            ["Managers dig up to 8h"],
            ["while you are away."],
            ["Selling: +2% per gold bar."]
        ];
    }
}

//! Prestige confirmation.
class SellDelegate extends WatchUi.ConfirmationDelegate {

    hidden var state as GameState;
    hidden var item as WatchUi.MenuItem;

    function initialize(gameState as GameState, menuItem as WatchUi.MenuItem) {
        ConfirmationDelegate.initialize();
        state = gameState;
        item = menuItem;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            if (state.sellMine()) {
                state.save();
                item.setSubLabel("Sold - " + state.bars.format("%d") + " bars held");
            }
            WatchUi.requestUpdate();
        }
        return true;
    }
}

//! Save wipe confirmation.
class WipeDelegate extends WatchUi.ConfirmationDelegate {

    hidden var state as GameState;

    function initialize(gameState as GameState) {
        ConfirmationDelegate.initialize();
        state = gameState;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            state.reset(true);
            state.save();
            WatchUi.requestUpdate();
        }
        return true;
    }
}

//! A simple full-screen text page. A row of one string is drawn centred; a
//! row of two is drawn as a label/value line across the width of the screen.
class PageView extends WatchUi.View {

    hidden var title as String;
    hidden var rows as Array<Array<String> >;

    function initialize(pageTitle as String, pageRows as Array<Array<String> >) {
        View.initialize();
        title = pageTitle;
        rows = pageRows;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_WHITE, 0x000000);
        dc.clear();

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_XTINY, title,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Keep the rows inside the widest band of the round display.
        var top = h * 20 / 100;
        var bottom = h * 86 / 100;
        var step = (bottom - top) / rows.size();
        var margin = w * 15 / 100;

        for (var i = 0; i < rows.size(); i++) {
            var y = top + step * i + step / 2;
            var row = rows[i];
            if (row.size() >= 2) {
                dc.setColor(0x9AA0AE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(margin, y, Graphics.FONT_XTINY, row[0],
                            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w - margin, y, Graphics.FONT_XTINY, row[1],
                            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            } else if (row.size() == 1) {
                dc.setColor(0xD7DBE3, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, y, Graphics.FONT_XTINY, row[0],
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }
}

//! Any tap or press closes a text page.
class PageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
