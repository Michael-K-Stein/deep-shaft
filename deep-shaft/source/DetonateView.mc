import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! Prestige. Blow the shaft, lose the run, keep the gems - the loop that makes
//! starting over feel like progress rather than punishment.
class DetonateView extends GameView {

    private var mW as Number = 0;
    private var mH as Number = 0;
    private var mButtonY as Number = 0;
    private var mButtonH as Number = 0;
    private var mButtonW as Number = 0;

    //! Frames left in the explosion animation, counted down to zero.
    private var mBlast as Number = 0;
    private var mAwarded as Number = 0;

    function initialize() {
        GameView.initialize();
    }

    function frameInterval() as Number {
        return 60;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mButtonH = (mH * 14) / 100;
        mButtonW = (mW * 55) / 100;
        mButtonY = (mH * 62) / 100;
    }

    function onAnimate() as Void {
        if (mBlast > 0) {
            mBlast -= 1;
            if (mBlast == 0) {
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
            }
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

        if (mBlast > 0) {
            drawBlast(dc);
            return;
        }

        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        dc.setColor(Theme.BAD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 12) / 100, Graphics.FONT_XTINY,
            Names.get(Rez.Strings.DetonateTitle).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        var pending = state.pendingGems();
        if (pending > 0) {
            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mW / 2, (mH * 24) / 100, Graphics.FONT_XTINY,
                Names.get(Rez.Strings.DetonateGain).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Theme.GEM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mW / 2, (mH * 32) / 100, Graphics.FONT_NUMBER_MEDIUM,
                pending.toString(), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mW / 2, (mH * 52) / 100, Graphics.FONT_XTINY,
                Names.get(Rez.Strings.GemBonus), Graphics.TEXT_JUSTIFY_CENTER);

            Theme.button(dc, (mW - mButtonW) / 2, mButtonY, mButtonW, mButtonH,
                Names.get(Rez.Strings.DetonateAction), Theme.BAD, Theme.TEXT);
        } else {
            var progress = (state.runEarned / Balance.DETONATE_MIN_EARNED).toFloat();
            if (progress > 1.0) {
                progress = 1.0;
            }
            drawWrapped(dc, Names.get(Rez.Strings.DetonateBody), (mH * 26) / 100);

            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mW / 2, (mH * 52) / 100, Graphics.FONT_XTINY,
                Fmt.big(state.runEarned) + " / "
                    + Fmt.big(Balance.DETONATE_MIN_EARNED),
                Graphics.TEXT_JUSTIFY_CENTER);

            Theme.ring(dc, mW / 2, mH / 2, mW / 2 - 6, 8, progress, Theme.BAD);

            Theme.button(dc, (mW - mButtonW) / 2, mButtonY, mButtonW, mButtonH,
                Names.get(Rez.Strings.DetonateAction), Theme.PANEL_HI, Theme.TEXT_DIM);
        }

        dc.setColor(Theme.GEM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 82) / 100, Graphics.FONT_XTINY,
            state.gems.toString() + " GEMS  +" + state.gemBonusPercent().toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Expanding shockwave rings, then the view pops itself.
    private function drawBlast(dc as Dc) as Void {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        var t = 1.0 - mBlast / 18.0;
        var maxR = mW / 2;
        for (var i = 0; i < 3; i += 1) {
            var r = ((t - i * 0.12) * maxR).toNumber();
            if (r > 4 && r < maxR) {
                dc.setPenWidth(10 - i * 3);
                dc.setColor(i == 0 ? Theme.GOLD : Theme.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(mW / 2, mH / 2, r);
            }
        }
        dc.setPenWidth(1);
        dc.setColor(Theme.GEM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, mH / 2 - 24, Graphics.FONT_MEDIUM,
            "+" + mAwarded.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Minimal word wrap - the body copy is the only multi-line text in the
    //! game, so a full text engine would be overkill.
    private function drawWrapped(dc as Dc, text as String, top as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var lineH = dc.getFontHeight(font) + 2;
        var maxWidth = (mW * 74) / 100;
        var words = split(text);
        var line = "";
        var y = top;
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < words.size(); i += 1) {
            var candidate = line.equals("") ? words[i] : line + " " + words[i];
            if (dc.getTextWidthInPixels(candidate, font) > maxWidth && !line.equals("")) {
                dc.drawText(mW / 2, y, font, line, Graphics.TEXT_JUSTIFY_CENTER);
                y += lineH;
                line = words[i];
            } else {
                line = candidate;
            }
        }
        if (!line.equals("")) {
            dc.drawText(mW / 2, y, font, line, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function split(text as String) as Array<String> {
        var out = [] as Array<String>;
        var current = "";
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            if (chars[i] == ' ') {
                if (!current.equals("")) {
                    out.add(current);
                    current = "";
                }
            } else {
                current += chars[i].toString();
            }
        }
        if (!current.equals("")) {
            out.add(current);
        }
        return out;
    }

    function hitButton(x as Number, y as Number) as Boolean {
        var left = (mW - mButtonW) / 2;
        return x >= left && x <= left + mButtonW
            && y >= mButtonY && y <= mButtonY + mButtonH;
    }

    function detonate() as Boolean {
        var state = DeepShaftApp.game();
        if (state == null) {
            return false;
        }
        var earned = state.detonate();
        if (earned <= 0) {
            return false;
        }
        mAwarded = earned;
        mBlast = 18;
        WatchUi.requestUpdate();
        return true;
    }

    function busy() as Boolean {
        return mBlast > 0;
    }
}
