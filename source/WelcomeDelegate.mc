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

    //! onKey, not onSelect: a real screen tap also fires the select behaviour
    //! with no coordinates, so relying on onSelect would dismiss the card
    //! twice per tap. Harmless here since both paths do the same thing, but
    //! onKey(KEY_ENTER) keeps every delegate in the codebase off onSelect,
    //! which is the rule tools/check_input.py enforces.
    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }
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
