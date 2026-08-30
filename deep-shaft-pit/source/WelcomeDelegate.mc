import Toybox.Lang;
import Toybox.WatchUi;

//! Any input collects the offline pile and returns to the mine.
class WelcomeDelegate extends WatchUi.BehaviorDelegate {

    private var mView as WelcomeView;

    function initialize(view as WelcomeView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        return dismiss();
    }

    function onSelect() as Boolean {
        return dismiss();
    }

    function onBack() as Boolean {
        return dismiss();
    }

    private function dismiss() as Boolean {
        mView.collect();
        Haptics.confirm();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
