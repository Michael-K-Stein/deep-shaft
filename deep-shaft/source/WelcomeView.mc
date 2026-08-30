import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "While you were away..." - the single most recognisable beat in the genre.
//! Shown once per launch when the crew mined something in your absence.
class WelcomeView extends GameView {

    private var mW as Number = 0;
    private var mH as Number = 0;
    private var mButtonY as Number = 0;
    private var mButtonH as Number = 0;
    private var mButtonW as Number = 0;
    private var mGain as Double = 0.0d;
    private var mSecs as Number = 0;

    function initialize() {
        GameView.initialize();
        var state = DeepShaftApp.game();
        if (state != null) {
            mGain = state.offlineGain;
            mSecs = state.offlineSecs;
        }
    }

    function frameInterval() as Number {
        return 200;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mButtonH = (mH * 14) / 100;
        mButtonW = (mW * 50) / 100;
        mButtonY = (mH * 70) / 100;
    }

    function onUpdate(dc as Dc) as Void {
        if (mW == 0) {
            onLayout(dc);
        }
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        dc.setColor(Theme.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (mH * 22) / 100, mW, (mH * 32) / 100);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 15) / 100, Graphics.FONT_XTINY,
            Names.get(Rez.Strings.WelcomeTitle).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 26) / 100, Graphics.FONT_NUMBER_MEDIUM,
            Fmt.big(mGain), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 45) / 100, Graphics.FONT_XTINY,
            Lang.format(Names.get(Rez.Strings.WelcomeSub), [Fmt.duration(mSecs)]),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 57) / 100, Graphics.FONT_XTINY,
            Names.get(Rez.Strings.WelcomeRate), Graphics.TEXT_JUSTIFY_CENTER);

        Theme.button(dc, (mW - mButtonW) / 2, mButtonY, mButtonW, mButtonH,
            Names.get(Rez.Strings.Collect), Theme.GOLD, 0x101018);
    }

    function collect() as Void {
        var state = DeepShaftApp.game();
        if (state != null) {
            state.collectOffline();
        }
    }
}
