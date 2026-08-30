import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Attention;
import Toybox.System;

//! Touch and button handling for the mine screen.
//!
//! Venu 2 has a touchscreen plus two buttons, so every action has both a tap
//! target and a key: tap a shaft to haul, tap its badge to hire a manager, tap
//! its price to upgrade. START rallies the crew, MENU opens the office.
class MineDelegate extends WatchUi.BehaviorDelegate {

    hidden var state as GameState;
    hidden var view as MineView;

    function initialize(gameState as GameState, mineView as MineView) {
        BehaviorDelegate.initialize();
        state = gameState;
        view = mineView;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (clearWelcome()) {
            return true;
        }
        var point = evt.getCoordinates();
        var x = point[0];
        var y = point[1];

        var action = view.actionAt(x, y);
        if (action >= 0) {
            runAction(action);
            return true;
        }

        var idx = view.rowAt(x, y);
        if (idx >= 0) {
            var zone = view.zoneAt(x);
            if (zone == :buy) {
                var before = state.level[idx];
                view.say(state.buyUpgrade(idx));
                if (state.level[idx] != before) {
                    buzz(35);
                }
            } else if (zone == :badge && !state.manager[idx]) {
                view.say(state.hireManager(idx));
                if (state.manager[idx]) {
                    buzz(60);
                }
            } else {
                view.say(state.workShaft(idx));
            }
            WatchUi.requestUpdate();
            return true;
        }
        return true;
    }

    //! The three buttons along the bottom of the mine screen.
    hidden function runAction(slot as Number) as Void {
        if (slot == 0) {
            if (state.boostReady()) {
                view.say(state.startBoost());
                buzz(60);
            } else if (state.boostMs > 0) {
                view.say("Double haul running");
            } else {
                view.say("Crew resting " + Fmt.duration(state.cooldownMs / 1000));
            }
        } else if (slot == 1) {
            state.buyMode = (state.buyMode + 1) % 3;
            view.say(view.buyModeLabel());
        } else {
            openMenu();
        }
        WatchUi.requestUpdate();
    }

    //! START: free 2x if it is off cooldown, otherwise send out every idle crew.
    function onSelect() as Boolean {
        if (clearWelcome()) {
            return true;
        }
        if (state.boostReady()) {
            view.say(state.startBoost());
            buzz(60);
        } else {
            var sent = 0;
            for (var i = 0; i < Balance.SHAFT_COUNT; i++) {
                if (state.level[i] > 0 && state.progress[i] < 0) {
                    state.workShaft(i);
                    sent++;
                }
            }
            if (sent > 0) {
                view.say(sent.format("%d") + " crews sent down");
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        if (clearWelcome()) {
            return true;
        }
        openMenu();
        return true;
    }

    function onBack() as Boolean {
        if (clearWelcome()) {
            return true;
        }
        state.save();
        return false;   // let the system leave the app
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        if (clearWelcome()) {
            return true;
        }
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.scrollBy(1);
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            view.scrollBy(-1);
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        view.scrollBy(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.scrollBy(-1);
        return true;
    }

    function openMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Mine Office" });
        menu.addItem(new WatchUi.MenuItem("Buy amount", view.buyModeLabel(), :buymode, {}));
        menu.addItem(new WatchUi.MenuItem("Hire all managers", null, :managers, {}));
        menu.addItem(new WatchUi.MenuItem("Sell the mine", sellSubLabel(), :sell, {}));
        menu.addItem(new WatchUi.MenuItem("Statistics", null, :stats, {}));
        menu.addItem(new WatchUi.MenuItem("How to play", null, :help, {}));
        menu.addItem(new WatchUi.MenuItem("Erase save", null, :wipe, {}));
        WatchUi.pushView(menu, new OfficeDelegate(state, view), WatchUi.SLIDE_UP);
    }

    hidden function sellSubLabel() as String {
        var pending = state.pendingBars();
        if (pending <= 0) {
            return "Needs " + Fmt.money(Balance.BAR_BASE) + " lifetime";
        }
        return "+" + pending.format("%d") + " gold bars";
    }

    //! Any input dismisses the offline-earnings card.
    hidden function clearWelcome() as Boolean {
        if (state.welcomeText == null) {
            return false;
        }
        state.welcomeText = null;
        WatchUi.requestUpdate();
        return true;
    }

    hidden function buzz(ms as Number) as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        if (!System.getDeviceSettings().vibrateOn) {
            return;
        }
        Attention.vibrate([new Attention.VibeProfile(40, ms)]);
    }
}
