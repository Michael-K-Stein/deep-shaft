import Toybox.Lang;
import Toybox.WatchUi;

//! Input for the dig screen. Tapping anywhere below the ring digs, so the
//! player does not have to hit a small target while walking.
class DigDelegate extends WatchUi.BehaviorDelegate {

    private var mView as DigView;

    function initialize(view as DigView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates();
        if (mView.hitButton(coords[0], coords[1]) && mView.dig()) {
            Haptics.confirm();
        }
        return true;
    }

    function onSelect() as Boolean {
        if (mView.dig()) {
            Haptics.confirm();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_UP);
        return true;
    }
}
