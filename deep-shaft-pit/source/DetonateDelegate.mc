import Toybox.Lang;
import Toybox.WatchUi;

//! Input for the prestige screen. The button is the only way through, so a
//! stray tap cannot wipe a run.
class DetonateDelegate extends WatchUi.BehaviorDelegate {

    private var mView as DetonateView;

    function initialize(view as DetonateView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        if (mView.busy()) {
            return true;
        }
        var coords = event.getCoordinates();
        if (mView.hitButton(coords[0], coords[1]) && mView.detonate()) {
            Haptics.boom();
        }
        return true;
    }

    function onBack() as Boolean {
        if (mView.busy()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
