import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Dig Deeper": the gold sink. Every level multiplies all income by 1.25x
//! and pushes the mine toward the next ore layer.
class DigView extends GameView {

    private var mW as Number = 0;
    private var mH as Number = 0;
    private var mButtonY as Number = 0;
    private var mButtonH as Number = 0;
    private var mButtonW as Number = 0;
    private var mFlash as Number = 0;

    function initialize() {
        GameView.initialize();
    }

    function frameInterval() as Number {
        return 120;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mButtonH = (mH * 14) / 100;
        mButtonW = (mW * 48) / 100;
        mButtonY = (mH * 64) / 100;
    }

    function onAnimate() as Void {
        if (mFlash > 0) {
            mFlash -= 1;
        }
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

        // Layer swatch behind the title, so the reward is visible not just read.
        var layer = state.layerIndex();
        dc.setColor(Theme.shade(Theme.layerColor(layer), 0.5), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (mH * 16) / 100, mW, (mH * 18) / 100);

        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 6) / 100, Graphics.FONT_TINY,
            Names.get(Rez.Strings.DigTitle).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 18) / 100, Graphics.FONT_MEDIUM,
            Names.layer(layer), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 27) / 100, Graphics.FONT_XTINY,
            state.depthMetres().toString() + Names.get(Rez.Strings.Metres)
                + "   " + Fmt.mult(state.multiplier()),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 40) / 100, Graphics.FONT_XTINY,
            Names.get(Rez.Strings.DigCost).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        var affordable = state.canDig();
        Theme.bigValue(dc, mW / 2, (mH * 47) / 100, state.depthCost(),
            affordable ? Theme.GOLD : Theme.TEXT_DIM, Graphics.FONT_NUMBER_MILD);

        Theme.ring(dc, mW / 2, mH / 2, mW / 2 - 6, 8, state.depthProgress(), Theme.GOLD);

        var fill = (mFlash > 0) ? Theme.GOOD : (affordable ? Theme.GOLD : Theme.PANEL_HI);
        var text = affordable || mFlash > 0 ? 0x101018 : Theme.TEXT_DIM;
        Theme.button(dc, (mW - mButtonW) / 2, mButtonY, mButtonW, mButtonH,
            Names.get(Rez.Strings.DigAction), fill, text);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 83) / 100, Graphics.FONT_XTINY,
            "+25% " + Names.get(Rez.Strings.DigBonus).toLower(),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function hitButton(x as Number, y as Number) as Boolean {
        var left = (mW - mButtonW) / 2;
        return x >= left && x <= left + mButtonW
            && y >= mButtonY && y <= mButtonY + mButtonH;
    }

    function dig() as Boolean {
        var state = DeepShaftApp.game();
        if (state == null || !state.dig()) {
            return false;
        }
        mFlash = 3;
        WatchUi.requestUpdate();
        return true;
    }
}
