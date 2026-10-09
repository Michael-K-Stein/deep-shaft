import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;

//! The hub menu and the shared push helpers. Keeping the push sites in one
//! place means every screen is reachable from every other one the same way.
module MainMenu {

    //! Replace with wherever tips should actually land (Ko-fi, PayPal.me, etc).
    const TIP_URL = "https://ko-fi.com/deepshaft";

    function push() as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.MenuTitle });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuCrew, Rez.Strings.MenuCrewSub, :crew, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDig, Rez.Strings.MenuDigSub, :dig, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDetonate, Rez.Strings.MenuDetonateSub, :detonate, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuStats, Rez.Strings.MenuStatsSub, :stats, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuOptions, Rez.Strings.MenuOptionsSub, :options, {}));
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function openCrew() as Void {
        var view = new CrewView();
        WatchUi.pushView(view, new CrewDelegate(view), WatchUi.SLIDE_UP);
    }

    function openDig() as Void {
        var view = new DigView();
        WatchUi.pushView(view, new DigDelegate(view), WatchUi.SLIDE_DOWN);
    }

    function openDetonate() as Void {
        var view = new DetonateView();
        WatchUi.pushView(view, new DetonateDelegate(view), WatchUi.SLIDE_LEFT);
    }

    function openStats() as Void {
        WatchUi.pushView(new StatsView(), new SimpleDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openOptions() as Void {
        var state = DeepShaftApp.game();
        var haptics = (state != null) ? state.haptics : true;
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.OptTitle });
        menu.addItem(new WatchUi.ToggleMenuItem(
            Rez.Strings.OptHaptics, null, :haptics, haptics, {}));
        menu.addItem(new WatchUi.MenuItem(
            Rez.Strings.OptWipe, Rez.Strings.OptWipeSub, :wipe, {}));
        menu.addItem(new WatchUi.MenuItem(
            Rez.Strings.OptTip, Rez.Strings.OptTipSub, :tip, {}));
        WatchUi.pushView(menu, new OptionsMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    //! Hands off to the paired phone's browser. There is no on-watch payment
    //! path in Connect IQ, so a tip is always a link opened on the phone.
    function openTip() as Void {
        if (!(Toybox has :Communications) || !(Communications has :openWebPage)) {
            WatchUi.pushView(
                new WatchUi.Confirmation(Names.get(Rez.Strings.OptTipNoPhone)),
                new SimpleDelegate(),
                WatchUi.SLIDE_UP);
            return;
        }
        Communications.openWebPage(TIP_URL, null, {});
    }
}

//! Routes hub-menu selections to the matching screen.
class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :crew) {
            MainMenu.openCrew();
        } else if (id == :dig) {
            MainMenu.openDig();
        } else if (id == :detonate) {
            MainMenu.openDetonate();
        } else if (id == :stats) {
            MainMenu.openStats();
        } else if (id == :options) {
            MainMenu.openOptions();
        }
    }
}

//! Haptics toggle plus a guarded save wipe.
class OptionsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var state = DeepShaftApp.game();
        if (state == null) {
            return;
        }
        var id = item.getId();
        if (id == :haptics && item instanceof WatchUi.ToggleMenuItem) {
            state.haptics = item.isEnabled();
            state.save();
            Haptics.tap();
        } else if (id == :wipe) {
            WatchUi.pushView(
                new WatchUi.Confirmation(Names.get(Rez.Strings.OptWipe)),
                new WipeConfirmationDelegate(),
                WatchUi.SLIDE_UP);
        } else if (id == :tip) {
            MainMenu.openTip();
        }
    }
}

//! Only a deliberate "yes" wipes the save.
class WipeConfirmationDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            var state = DeepShaftApp.game();
            if (state != null) {
                state.wipe();
            }
            Haptics.boom();
        }
        return true;
    }
}

//! Back-only input, for screens that are pure read-outs.
class SimpleDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
