import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The shop. Three rows at a time, a bulk-buy chip, and a running gold total
//! at the top so the player can watch a purchase become affordable.
class CrewView extends GameView {

    //! Buy quantities the chip cycles through. 0 means "as many as possible".
    private const QUANTITIES = [1, 10, 0];

    private var mTop as Number = 0;          // index of the first visible row
    private var mQuantityIndex as Number = 0;
    private var mFlashRow as Number = -1;    // row that just got bought
    private var mFlashFrames as Number = 0;

    private var mW as Number = 0;
    private var mH as Number = 0;
    private var mHeaderH as Number = 0;
    private var mRowH as Number = 0;
    private var mRowTop as Number = 0;
    private var mVisibleRows as Number = 3;

    function initialize() {
        GameView.initialize();
    }

    function frameInterval() as Number {
        return 120;
    }

    function onLayout(dc as Dc) as Void {
        mW = dc.getWidth();
        mH = dc.getHeight();
        mHeaderH = (mH * 26) / 100;
        mRowTop = mHeaderH;
        mRowH = (mH * 21) / 100;
        mVisibleRows = (mH - mRowTop - (mH * 6) / 100) / mRowH;
        if (mVisibleRows < 1) {
            mVisibleRows = 1;
        }
    }

    function onAnimate() as Void {
        if (mFlashFrames > 0) {
            mFlashFrames -= 1;
            if (mFlashFrames == 0) {
                mFlashRow = -1;
            }
        }
    }

    // --------------------------------------------------------------- drawing

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

        clampScroll(state);

        var count = state.revealedCount();
        for (var slot = 0; slot < mVisibleRows; slot += 1) {
            var position = mTop + slot;
            if (position < count) {
                drawRow(dc, state, crewAt(state, position), mRowTop + slot * mRowH);
            }
        }

        drawHeader(dc, state);
        drawScrollbar(dc, count);
    }

    private function drawHeader(dc as Dc, state as GameState) as Void {
        dc.setColor(Theme.BG, Theme.BG);
        dc.fillRectangle(0, 0, mW, mHeaderH);

        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mW / 2, (mH * 5) / 100, Graphics.FONT_MEDIUM,
            Fmt.big(state.gold), Graphics.TEXT_JUSTIFY_CENTER);

        var chip = quantityLabel();
        var box = chipBox();
        Theme.button(dc, box[0], box[1], box[2], box[3], chip, Theme.PANEL_HI, Theme.TEXT);

        dc.setColor(Theme.PANEL_HI, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, mHeaderH - 2, mW, 2);
    }

    private function drawRow(dc as Dc, state as GameState, index as Number, y as Number) as Void {
        var owned = state.crew[index] as Number;
        var quantity = quantityFor(state, index);
        var price = (quantity > 0) ? state.crewBundleCost(index, quantity)
                                   : state.crewCost(index, owned);
        var affordable = quantity > 0 && price <= state.gold;

        // Fit the row to the narrowest of its own top and bottom edges,
        // otherwise the corners of a row near the bezel fall off the glass.
        var radius = mW / 2 - 4;
        var top = Theme.chordHalfWidth(radius, y + 3 - mH / 2);
        var bottom = Theme.chordHalfWidth(radius, y + mRowH - 5 - mH / 2);
        var half = (top < bottom) ? top : bottom;
        if (half < 40) {
            return;
        }
        var x = mW / 2 - half;
        var w = half * 2;

        var fill = (index == mFlashRow) ? Theme.GOLD_DIM : Theme.PANEL;
        Theme.panel(dc, x, y + 3, w, mRowH - 8, 10, fill,
            affordable ? Theme.GOLD_DIM : null);

        // Lay the row out from the real font metrics rather than from fixed
        // offsets: the two text lines, the price column and the milestone bar
        // all have to share a panel only ~20% of the screen tall, and guessed
        // offsets put the second line through the bottom edge.
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var panelBottom = y + mRowH - 5;
        var barY = panelBottom - 7;

        var priceText = Fmt.big(price);
        var priceW = dc.getTextWidthInPixels(priceText, Graphics.FONT_TINY);
        var textLeft = x + 14;
        var textRight = x + w - 14 - priceW - 10;

        var nameY = y + 7;
        var rateY = nameY + lineH;

        var name = Names.crew(index);
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textLeft, nameY, Graphics.FONT_XTINY,
            name, Graphics.TEXT_JUSTIFY_LEFT);

        // Banked milestone doublings ride after the name, in gold, but only
        // when they fit clear of the price column.
        var steps = state.crewMilestones(index);
        if (steps > 0) {
            var badge = Fmt.mult(state.crewMilestoneMult(index));
            var badgeX = textLeft
                + dc.getTextWidthInPixels(name, Graphics.FONT_XTINY) + 8;
            if (badgeX + dc.getTextWidthInPixels(badge, Graphics.FONT_XTINY)
                    <= textRight) {
                dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
                dc.drawText(badgeX, nameY, Graphics.FONT_XTINY, badge,
                    Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textLeft, rateY, Graphics.FONT_XTINY,
            owned.toString() + " x " + Fmt.rate(state.crewUnitRate(index))
                + Names.get(Rez.Strings.PerSec),
            Graphics.TEXT_JUSTIFY_LEFT);

        var priceColor = affordable ? Theme.GOLD : Theme.TEXT_DIM;
        dc.setColor(priceColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w - 14, y + (mRowH - 8) / 2, Graphics.FONT_TINY,
            priceText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        drawMilestoneBar(dc, state, index, textLeft, barY, w - 28);
    }

    //! A hairline under each row tracking progress to the next doubling. It
    //! is deliberately thin: it should read as a nudge toward "a few more of
    //! these" without competing with the price for attention.
    private function drawMilestoneBar(dc as Dc, state as GameState, index as Number,
                                      x as Number, y as Number, w as Number) as Void {
        var done = Balance.MILESTONE_EVERY - state.crewToNextMilestone(index);
        dc.setColor(Theme.PANEL_HI, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, 3);
        if (done > 0) {
            dc.setColor(Theme.GOLD_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, w * done / Balance.MILESTONE_EVERY, 3);
        }
    }

    private function drawScrollbar(dc as Dc, count as Number) as Void {
        if (count <= mVisibleRows) {
            return;
        }
        var trackTop = mRowTop;
        var trackH = mVisibleRows * mRowH;
        var thumbH = trackH * mVisibleRows / count;
        var thumbY = trackTop + trackH * mTop / count;
        dc.setColor(Theme.PANEL_HI, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mW - 10, trackTop, 4, trackH, 2);
        dc.setColor(Theme.GOLD_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mW - 10, thumbY, 4, thumbH, 2);
    }

    // ------------------------------------------------------------ behaviour

    private function clampScroll(state as GameState) as Void {
        var count = state.revealedCount();
        var maxTop = count - mVisibleRows;
        if (maxTop < 0) {
            maxTop = 0;
        }
        if (mTop > maxTop) {
            mTop = maxTop;
        }
        if (mTop < 0) {
            mTop = 0;
        }
    }

    function scroll(delta as Number) as Void {
        mTop += delta;
        var state = DeepShaftApp.game();
        if (state != null) {
            clampScroll(state);
        }
        WatchUi.requestUpdate();
    }

    function cycleQuantity() as Void {
        mQuantityIndex = (mQuantityIndex + 1) % QUANTITIES.size();
        WatchUi.requestUpdate();
    }

    private function quantityLabel() as String {
        var q = (QUANTITIES as Array<Number>)[mQuantityIndex];
        if (q == 1) {
            return "x1";
        }
        if (q == 10) {
            return "x10";
        }
        return "MAX";
    }

    //! How many units the current chip setting would buy for this row.
    private function quantityFor(state as GameState, index as Number) as Number {
        var q = (QUANTITIES as Array<Number>)[mQuantityIndex];
        if (q > 0) {
            return q;
        }
        var max = state.crewMaxAffordable(index);
        return (max > 0) ? max : 1;
    }

    private function chipBox() as Array<Number> {
        var w = (mW * 22) / 100;
        var h = (mH * 9) / 100;
        return [mW / 2 - w / 2, mHeaderH - h - 6, w, h] as Array<Number>;
    }

    //! Crew index drawn at display position `position`, counting from the top.
    //!
    //! The shop runs richest-first. By the late game the opening tiers are
    //! rounding errors that the player never buys again, so putting them first
    //! meant scrolling past dead rows every visit. This way the useful end of
    //! the list is the end you land on, and a tier that has just unlocked -
    //! always the most expensive one - appears at the top.
    private function crewAt(state as GameState, position as Number) as Number {
        return state.revealedCount() - 1 - position;
    }

    //! Row under a touch point, or -1.
    function rowAt(x as Number, y as Number) as Number {
        if (y < mRowTop) {
            return -1;
        }
        var slot = (y - mRowTop) / mRowH;
        if (slot < 0 || slot >= mVisibleRows) {
            return -1;
        }
        var state = DeepShaftApp.game();
        if (state == null) {
            return -1;
        }
        var position = mTop + slot;
        return (position < state.revealedCount()) ? crewAt(state, position) : -1;
    }

    function hitChip(x as Number, y as Number) as Boolean {
        var box = chipBox();
        return x >= box[0] && x <= box[0] + box[2]
            && y >= box[1] && y <= box[1] + box[3];
    }

    //! Quick-buy for the physical button: the best crew type currently
    //! affordable, which is nearly always the right call.
    function buyBest() as Boolean {
        var state = DeepShaftApp.game();
        if (state == null) {
            return false;
        }
        for (var i = state.revealedCount() - 1; i >= 0; i -= 1) {
            if (state.gold >= state.crewCost(i, state.crew[i] as Number)) {
                return buy(i);
            }
        }
        return false;
    }

    //! Buy into a row, returning true when something was actually bought.
    function buy(index as Number) as Boolean {
        var state = DeepShaftApp.game();
        if (state == null) {
            return false;
        }
        var bought = state.buyCrew(index, quantityFor(state, index));
        if (bought > 0) {
            mFlashRow = index;
            mFlashFrames = 3;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
