import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Base for every screen in the game. It owns the frame timer, advances the
//! simulation from wall-clock time and asks for a redraw. Only one view is
//! visible at a time, so exactly one of these timers is ever running.
class GameView extends WatchUi.View {

    protected var mFrame as Number = 0;
    private var mTimer as Timer.Timer or Null = null;

    function initialize() {
        View.initialize();
    }

    //! Redraw period in milliseconds. Animated screens override this.
    function frameInterval() as Number {
        return 200;
    }

    function onShow() as Void {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
            (mTimer as Timer.Timer).start(method(:onFrame), frameInterval(), true);
        }
    }

    function onHide() as Void {
        if (mTimer != null) {
            (mTimer as Timer.Timer).stop();
            mTimer = null;
        }
        var state = DeepShaftApp.game();
        if (state != null) {
            state.save();
        }
    }

    function onFrame() as Void {
        var state = DeepShaftApp.game();
        if (state != null) {
            state.tick();
        }
        mFrame += 1;
        onAnimate();
        WatchUi.requestUpdate();
    }

    //! Hook for per-frame animation bookkeeping.
    function onAnimate() as Void {
    }
}
