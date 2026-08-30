import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Deep Shaft Tycoon - an idle mining empire for the Venu 2 family.
class DeepShaftApp extends Application.AppBase {

    var state as GameState;
    var view as MineView?;

    function initialize() {
        AppBase.initialize();
        state = new GameState();
    }

    function onStart(startState as Dictionary?) as Void {
        state.load();
    }

    function onStop(stopState as Dictionary?) as Void {
        state.save();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var mineView = new MineView(state);
        view = mineView;
        return [mineView, new MineDelegate(state, mineView)];
    }
}
