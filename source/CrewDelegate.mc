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

    //! The physical START button buys the most expensive thing you can afford,
    //! which is almost always what the player wants.
    function onSelect() as Boolean {
        if (mView.buyBest()) {
            Haptics.confirm();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
