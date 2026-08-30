import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Read-only summary of the run and of everything before it.
class StatsView extends GameView {

    private var mW as Number = 0;
    private var mH as Number = 0;

    function initialize() {
        GameView.initialize();
    }

    function frameInterval() as Number {
        return 500;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
    }

    function onUpdate(dc as Dc) as Void {
        var state = DeepShaftApp.game();
        if (state == null) {
            return;
        }
        if (mW == 0) {
            onLayout(dc);
        }
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 6) / 100, Graphics.FONT_XTINY,
            Names.get(Rez.Strings.StatsTitle).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        // Seven rows now, so they start a little higher up the glass.
        var y = (mH * 15) / 100;
        y = row(dc, y, Names.get(Rez.Strings.StatRun), Fmt.big(state.runEarned), Theme.GOLD);
        y = row(dc, y, Names.get(Rez.Strings.StatLifetime), Fmt.big(state.lifetimeEarned), Theme.GOLD);
        y = row(dc, y, Names.get(Rez.Strings.StatGems), state.gems.toString(), Theme.GEM);
        y = row(dc, y, Names.get(Rez.Strings.StatDetonations), state.detonations.toString(), Theme.ACCENT);
        y = row(dc, y, Names.get(Rez.Strings.StatTaps), state.swings.toString(), Theme.TEXT);
        y = row(dc, y, Names.get(Rez.Strings.StatStrikes), state.strikes.toString(), Theme.GOLD);
        y = row(dc, y, Names.get(Rez.Strings.StatPlayed), Fmt.duration(state.playedSecs), Theme.TEXT);
    }

    //! One label/value pair, inset to stay inside the round glass.
    private function row(dc as Dc, y as Number, label as String, value as String,
                         color as Number) as Number {
        var half = Theme.chordHalfWidth(mW / 2 - 10, y + 12 - mH / 2);
        if (half < 40) {
            return y + (mH * 12) / 100;
        }
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2 - half, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2 + half, y, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
        return y + (mH * 12) / 100;
    }
}
