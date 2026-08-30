import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Deep Shaft - an idle mining tycoon.
//!
//! The shape is lifted straight from the idle-game ads everyone has scrolled
//! past: hire a crew that digs while you are away, sink the profits into
//! deeper shafts, then blow the whole mine up for a permanent multiplier and
//! do it again faster.
class DeepShaftApp extends Application.AppBase {

    private var mState as GameState or Null = null;

    //! Convenience accessor so views do not have to cast the app every time.
    static function game() as GameState or Null {
        return (Application.getApp() as DeepShaftApp).state();
    }

    function initialize() {
        AppBase.initialize();
    }

    function state() as GameState or Null {
        return mState;
    }

    function onStart(startState as Dictionary?) as Void {
        mState = new GameState();
        (mState as GameState).load();
    }

    function onStop(stopState as Dictionary?) as Void {
        if (mState != null) {
            (mState as GameState).save();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new MineView();
        return [view, new MineDelegate(view)];
    }
}
