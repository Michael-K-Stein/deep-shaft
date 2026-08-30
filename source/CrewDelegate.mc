import Toybox.Lang;
import Toybox.WatchUi;

//! Input for the crew screen: tap a row to buy, tap the chip to change the
//! bulk amount, swipe or page keys to scroll, START to quick-buy.
class CrewDelegate extends WatchUi.BehaviorDelegate {

    private var mView as CrewView;

    function initialize(view as CrewView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coords = event.getCoordinates();
        var x = coords[0];
        var y = coords[1];
        if (mView.hitChip(x, y)) {
            mView.cycleQuantity();
            return true;
        }
        var row = mView.rowAt(x, y);
        if (row >= 0 && mView.buy(row)) {
            Haptics.confirm();
        }
        return true;
    }

    function onNextPage() as Boolean {
        mView.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        mView.scroll(-1);
        return true;
    }

    //! Quick-buy hangs off the raw key event, not off onSelect. A screen tap
    //! also arrives as the *select behaviour* on this hardware, and it does so
    //! without any coordinates - so an onSelect that called buyBest() turned
    //! every tap anywhere into "buy the most expensive crew", ignoring both
    //! the row under the finger and the quantity chip. onKey(KEY_ENTER) is
    //! reached only by the physical button, so the two gestures stay apart.
    //! Every other key falls through to its behaviour, which is what keeps the
    //! page keys scrolling.
    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER) {
            if (mView.buyBest()) {
                Haptics.confirm();
            }
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
