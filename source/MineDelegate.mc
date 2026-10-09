import Toybox.Lang;
import Toybox.WatchUi;

//! Input for the home screen.
//!
//!   tap / START  - swing the pick, or grab a lucky vein when one is up
//!   tap the pill - open the crew screen
//!   swipe up     - crew, swipe down - dig deeper, swipe left - detonate
//!   MENU         - the hub menu
class MineDelegate extends WatchUi.BehaviorDelegate {

    private var mView as MineView;

    function initialize(view as MineView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates();
        var x = coords[0];
        var y = coords[1];
        if (mView.hitStrike(x, y)) {
            mView.claimStrike();
            Haptics.confirm();
            WatchUi.requestUpdate();
            return true;
        }
        if (mView.hitCrewButton(x, y)) {
            openCrew();
            return true;
        }
        doSwing(x, y - 30);
        return true;
    }

    //! START takes the vein when one is up - it is worth far more than a
    //! swing, and fumbling for it on a small screen would be a shame.
    //!
    //! This hangs off the raw key event, not onSelect: on this hardware a
    //! screen tap also arrives as the select behaviour, with no coordinates,
    //! so an onSelect override fired a second, center-screen swing right
    //! after onTap had already handled the real one - which is why every tap
    //! looked like it landed dead center. onKey(KEY_ENTER) is reached only by
    //! the physical START button, so the two gestures stay apart.
    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }
        if (mView.strikeLive()) {
            mView.claimStrike();
            Haptics.confirm();
            WatchUi.requestUpdate();
            return true;
        }
        doSwing(-1, -1);
        return true;
    }

    function onMenu() as Boolean {
        MainMenu.push();
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        var direction = event.getDirection();
        if (direction == WatchUi.SWIPE_UP) {
            openCrew();
            return true;
        }
        if (direction == WatchUi.SWIPE_DOWN) {
            MainMenu.openDig();
            return true;
        }
        if (direction == WatchUi.SWIPE_LEFT) {
            MainMenu.openDetonate();
            return true;
        }
        return false;
    }

    private function openCrew() as Void {
        var view = new CrewView();
        WatchUi.pushView(view, new CrewDelegate(view), WatchUi.SLIDE_UP);
    }

    //! Pass (-1, -1) to pop the "+gold" label at the default spot.
    private function doSwing(x as Number, y as Number) as Void {
        var state = DeepShaftApp.game();
        if (state == null) {
            return;
        }
        var value = state.swing();
        var px = (x < 0) ? mView.width() / 2 : x;
        var py = (y < 0) ? mView.height() / 2 : y;
        mView.registerSwing(value, px, py);
        Haptics.tap();
        WatchUi.requestUpdate();
    }
}
