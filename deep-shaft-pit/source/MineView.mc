import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! The home screen: how much gold you have, how fast it is coming in, and a
//! miner swinging a pick at the rock face.
class MineView extends GameView {

    private const MAX_POPS = 5;
    private const MAX_ORE = 12;
    private const BAND_HEIGHT = 26;

    // Floating "+123" labels spawned by a swing.
    private var mPopLife as Array<Float>;
    private var mPopX as Array<Number>;
    private var mPopY as Array<Float>;
    private var mPopText as Array<String>;

    // Ore chips knocked loose by the pick.
    private var mOreLife as Array<Float>;
    private var mOreX as Array<Float>;
    private var mOreY as Array<Float>;
    private var mOreVX as Array<Float>;
    private var mOreVY as Array<Float>;

    private var mSwingPhase as Float = 0.0;
    private var mLastPhase as Float = 0.0;
    private var mDrift as Float = 0.0;
    private var mWelcomeDone as Boolean = false;
    private var mWelcomeTimer as Timer.Timer or Null = null;

    // Geometry, resolved once the device tells us the screen size.
    private var mW as Number = 0;
    private var mH as Number = 0;
    private var mGroundY as Number = 0;
    private var mShaftX as Number = 0;
    private var mShaftW as Number = 0;
    private var mDiggerY as Number = 0;
    private var mCrewButtonY as Number = 0;
    private var mCrewButtonH as Number = 0;
    private var mCrewButtonW as Number = 0;

    function initialize() {
        GameView.initialize();
        mPopLife = new [MAX_POPS] as Array<Float>;
        mPopX = new [MAX_POPS] as Array<Number>;
        mPopY = new [MAX_POPS] as Array<Float>;
        mPopText = new [MAX_POPS] as Array<String>;
        for (var i = 0; i < MAX_POPS; i += 1) {
            mPopLife[i] = 0.0;
            mPopX[i] = 0;
            mPopY[i] = 0.0;
            mPopText[i] = "";
        }
        mOreLife = new [MAX_ORE] as Array<Float>;
        mOreX = new [MAX_ORE] as Array<Float>;
        mOreY = new [MAX_ORE] as Array<Float>;
        mOreVX = new [MAX_ORE] as Array<Float>;
        mOreVY = new [MAX_ORE] as Array<Float>;
        for (var j = 0; j < MAX_ORE; j += 1) {
            mOreLife[j] = 0.0;
            mOreX[j] = 0.0;
            mOreY[j] = 0.0;
            mOreVX[j] = 0.0;
            mOreVY[j] = 0.0;
        }
    }

    //! 20 fps: smooth enough for the pick swing without hammering the battery.
    function frameInterval() as Number {
        return 50;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mGroundY = (mH * 52) / 100;
        mShaftW = (mW * 32) / 100;
        mShaftX = (mW - mShaftW) / 2;
        mDiggerY = mGroundY + (mH - mGroundY) * 40 / 100;
        mCrewButtonH = (mH * 12) / 100;
        mCrewButtonW = (mW * 38) / 100;
        mCrewButtonY = mH - mCrewButtonH - (mH * 6) / 100;
    }

    function onShow() as Void {
        GameView.onShow();
        // The welcome-back card is pushed from a one-shot timer: pushing a
        // view from inside onShow() is not safe.
        var state = DeepShaftApp.game();
        if (!mWelcomeDone && state != null && state.offlineGain > 0.0d) {
            mWelcomeDone = true;
            mWelcomeTimer = new Timer.Timer();
            (mWelcomeTimer as Timer.Timer).start(method(:showWelcome), 350, false);
        }
    }

    function onHide() as Void {
        if (mWelcomeTimer != null) {
            (mWelcomeTimer as Timer.Timer).stop();
            mWelcomeTimer = null;
        }
        GameView.onHide();
    }

    function showWelcome() as Void {
        mWelcomeTimer = null;
        var state = DeepShaftApp.game();
        if (state != null && state.offlineGain > 0.0d) {
            var view = new WelcomeView();
            WatchUi.pushView(view, new WelcomeDelegate(view), WatchUi.SLIDE_UP);
        }
    }

    // ------------------------------------------------------------ animation

    function onAnimate() as Void {
        var dt = frameInterval() / 1000.0;
        mDrift += dt * 6.0;
        if (mDrift >= BAND_HEIGHT) {
            mDrift -= BAND_HEIGHT;
        }

        mLastPhase = mSwingPhase;
        mSwingPhase += dt * 0.75;
        while (mSwingPhase >= 1.0) {
            mSwingPhase -= 1.0;
        }
        // The pick bottoms out at phase 0.5; that is when chips fly.
        if (mLastPhase < 0.5 && mSwingPhase >= 0.5) {
            spawnOre(3);
        }

        for (var i = 0; i < MAX_POPS; i += 1) {
            if (mPopLife[i] > 0.0) {
                mPopLife[i] = mPopLife[i] - dt;
                mPopY[i] = mPopY[i] - 34.0 * dt;
            }
        }
        for (var j = 0; j < MAX_ORE; j += 1) {
            if (mOreLife[j] > 0.0) {
                mOreLife[j] = mOreLife[j] - dt;
                mOreVY[j] = mOreVY[j] + 320.0 * dt;
                mOreX[j] = mOreX[j] + mOreVX[j] * dt;
                mOreY[j] = mOreY[j] + mOreVY[j] * dt;
            }
        }
    }

    //! Called by the delegate when the player swings.
    function registerSwing(value as Double, x as Number, y as Number) as Void {
        for (var i = 0; i < MAX_POPS; i += 1) {
            if (mPopLife[i] <= 0.0) {
                mPopLife[i] = 0.9;
                mPopX[i] = x;
                mPopY[i] = y.toFloat();
                mPopText[i] = "+" + Fmt.big(value);
                break;
            }
        }
        spawnOre(4);
    }

    private function spawnOre(count as Number) as Void {
        var spawned = 0;
        var tip = pickTip();
        for (var i = 0; i < MAX_ORE && spawned < count; i += 1) {
            if (mOreLife[i] <= 0.0) {
                mOreLife[i] = 0.55 + (i % 3) * 0.12;
                mOreX[i] = tip[0].toFloat();
                mOreY[i] = tip[1].toFloat();
                mOreVX[i] = -70.0 + (i % 5) * 34.0;
                mOreVY[i] = -110.0 - (i % 4) * 25.0;
                spawned += 1;
            }
        }
    }

    //! Current pick angle in degrees, positive is raised.
    private function pickAngle() as Float {
        return 12.5 + 32.5 * Math.cos(mSwingPhase * 2.0 * Math.PI).toFloat();
    }

    private function shoulder() as Array<Number> {
        return [mW / 2 + 10, mDiggerY - 8] as Array<Number>;
    }

    private function pickTip() as Array<Number> {
        var s = shoulder();
        var rad = pickAngle() * Math.PI / 180.0;
        var len = 40;
        return [
            s[0] + (len * Math.cos(rad)).toNumber(),
            s[1] - (len * Math.sin(rad)).toNumber()
        ] as Array<Number>;
    }

    // -------------------------------------------------------------- drawing

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

        drawStrata(dc, state);
        drawShaft(dc, state);
        drawDigger(dc);
        drawOre(dc);
        drawHud(dc, state);
        drawPops(dc);
        drawCrewButton(dc, state);

        Theme.ring(dc, mW / 2, mH / 2, mW / 2 - 6, 8, state.depthProgress(), Theme.GOLD);
    }

    //! Horizontal rock bands below the surface, tinted by the current layer
    //! and drifting slowly downward so the mine always feels alive.
    private function drawStrata(dc as Dc, state as GameState) as Void {
        var base = Theme.layerColor(state.layerIndex());
        var y = mGroundY - BAND_HEIGHT + mDrift.toNumber();
        var index = 0;
        while (y < mH) {
            var k = 0.30 + 0.13 * (index % 3);
            dc.setColor(Theme.shade(base, k), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, y, mW, BAND_HEIGHT);
            y += BAND_HEIGHT;
            index += 1;
        }
        // Surface line with a warm glow, the boundary between sky and rock.
        dc.setColor(Theme.shade(base, 0.85), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, mGroundY, mW, 3);
    }

    //! The vertical cut the crew is working, drawn darker than the rock.
    private function drawShaft(dc as Dc, state as GameState) as Void {
        dc.setColor(0x08080C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mShaftX, mGroundY, mShaftW, mH - mGroundY);

        var edge = Theme.shade(Theme.layerColor(state.layerIndex()), 0.95);
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mShaftX, mGroundY, 3, mH - mGroundY);
        dc.fillRectangle(mShaftX + mShaftW - 3, mGroundY, 3, mH - mGroundY);

        // Support beams every so often down the shaft.
        dc.setColor(Theme.shade(0x8C5A3C, 0.7), Graphics.COLOR_TRANSPARENT);
        var y = mGroundY + 22;
        while (y < mH) {
            dc.fillRectangle(mShaftX, y, mShaftW, 4);
            y += 58;
        }
    }

    private function drawDigger(dc as Dc) as Void {
        var cx = mW / 2;
        var y = mDiggerY;

        // Legs and body.
        dc.setColor(0x2E4A8C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 11, y - 12, 8, 24);
        dc.fillRectangle(cx + 3, y - 12, 8, 24);
        dc.setColor(0x3A5AA0, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 13, y - 34, 26, 26, 6);

        // Head and hard hat.
        dc.setColor(0xD8A87A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, y - 42, 9);
        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 13, y - 48, 26, 5);
        dc.fillCircle(cx, y - 50, 9);

        // Head lamp, and the cone of light it throws on the rock face.
        dc.setColor(0xFFF2C0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 7, y - 52, 3);

        // Arm and pick.
        var s = shoulder();
        var tip = pickTip();
        dc.setPenWidth(6);
        dc.setColor(0x8C5A3C, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(s[0], s[1], tip[0], tip[1]);
        dc.setPenWidth(1);
        dc.setColor(0xC8D0D8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tip[0], tip[1], 5);
    }

    private function drawOre(dc as Dc) as Void {
        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < MAX_ORE; i += 1) {
            if (mOreLife[i] > 0.0) {
                var size = (mOreLife[i] > 0.3) ? 5 : 3;
                dc.fillRectangle(mOreX[i].toNumber(), mOreY[i].toNumber(), size, size);
            }
        }
    }

    private function drawPops(dc as Dc) as Void {
        for (var i = 0; i < MAX_POPS; i += 1) {
            if (mPopLife[i] > 0.0) {
                var color = (mPopLife[i] > 0.35) ? Theme.GOLD : Theme.GOLD_DIM;
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mPopX[i], mPopY[i].toNumber(), Graphics.FONT_XTINY,
                    mPopText[i], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    //! Everything here sits between 11% and 44% of the screen height, which is
    //! the widest part of a round display. The gem line and the tap hint share
    //! one slot: a player with gems has long since stopped needing the hint.
    private function drawHud(dc as Dc, state as GameState) as Void {
        var cx = mW / 2;

        dc.setColor(Theme.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 11) / 100, Graphics.FONT_TINY,
            Names.layer(state.layerIndex()).toUpper() + "  "
                + state.depthMetres().toString() + Names.get(Rez.Strings.Metres),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 19) / 100, Graphics.FONT_NUMBER_MEDIUM,
            Fmt.big(state.gold), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (mH * 36) / 100, Graphics.FONT_TINY,
            Fmt.rate(state.ratePerSecond()) + Names.get(Rez.Strings.PerSec),
            Graphics.TEXT_JUSTIFY_CENTER);

        if (state.gems > 0) {
            dc.setColor(Theme.GEM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 44) / 100, Graphics.FONT_XTINY,
                state.gems.toString() + " GEMS  +" + state.gemBonusPercent().toString() + "%",
                Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state.swings < 5) {
            // Only nag about tapping until the player has worked it out.
            dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (mH * 44) / 100, Graphics.FONT_XTINY,
                Names.get(Rez.Strings.TapHint), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawCrewButton(dc as Dc, state as GameState) as Void {
        var x = (mW - mCrewButtonW) / 2;
        var affordable = false;
        for (var i = 0; i < Balance.CREW_COUNT && !affordable; i += 1) {
            if (state.crewRevealed(i) && state.gold >= state.crewCost(i, state.crew[i] as Number)) {
                affordable = true;
            }
        }
        var fill = affordable ? Theme.GOLD : Theme.PANEL_HI;
        var text = affordable ? 0x101018 : Theme.TEXT_DIM;
        Theme.button(dc, x, mCrewButtonY, mCrewButtonW, mCrewButtonH,
            Names.get(Rez.Strings.CrewTitle).toUpper(), fill, text);
    }

    function width() as Number {
        return mW;
    }

    function height() as Number {
        return mH;
    }

    //! True when (x, y) is inside the crew button.
    function hitCrewButton(x as Number, y as Number) as Boolean {
        var left = (mW - mCrewButtonW) / 2;
        return x >= left && x <= left + mCrewButtonW
            && y >= mCrewButtonY && y <= mCrewButtonY + mCrewButtonH;
    }
}
