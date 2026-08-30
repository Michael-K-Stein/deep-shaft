import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Colours and shared drawing primitives. The palette is deliberately dark:
//! the Venu 2 is AMOLED, so black pixels cost no battery.
module Theme {

    const BG = 0x000000;
    const PANEL = 0x101018;
    const PANEL_HI = 0x1E1E2A;
    const GOLD = 0xFFC61E;
    const GOLD_DIM = 0x8A6A10;
    const TEXT = 0xFFFFFF;
    const TEXT_DIM = 0x9098A8;
    const ACCENT = 0xFF6B1A;
    const GOOD = 0x2ED573;
    const BAD = 0xE04030;
    const GEM = 0x4FC3E8;

    //! Space between a number and its magnitude suffix.
    const GAP = 3;

    //! One colour per ore layer, used for the strata behind the main screen.
    const LAYER_COLOR = [
        0x6B4A2F,   // topsoil
        0x8C5A3C,   // clay
        0x8A8F96,   // limestone
        0x565B66,   // granite
        0x33334A,   // obsidian
        0xB3300F,   // magma
        0x2E9BB5,   // crystal
        0xC8D0D8,   // neutronium
        0xE0409A,   // antimatter
        0x3A1E5C,   // singularity
        0x2ED573,   // genesis
        0x5B2E8C    // the void
    ];

    function layerColor(index as Number) as Number {
        var i = index;
        if (i < 0) {
            i = 0;
        }
        if (i >= LAYER_COLOR.size()) {
            i = LAYER_COLOR.size() - 1;
        }
        return (LAYER_COLOR as Array<Number>)[i];
    }

    //! Darken a packed 0xRRGGBB colour toward black. `amount` is 0..1.
    function shade(color as Number, amount as Number or Float) as Number {
        var k = amount;
        if (k < 0.0) {
            k = 0.0;
        }
        if (k > 1.0) {
            k = 1.0;
        }
        var r = ((color >> 16) & 0xFF) * k;
        var g = ((color >> 8) & 0xFF) * k;
        var b = (color & 0xFF) * k;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }

    //! Filled panel with a one-pixel lighter edge, the game's basic surface.
    function panel(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                   radius as Number, fill as Number, edge as Number or Null) as Void {
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, radius);
        if (edge != null) {
            dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(x, y, w, h, radius);
            dc.setPenWidth(1);
        }
    }

    //! A pill-shaped button. Returns nothing; hit testing lives in the views.
    function button(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                    label as String, fill as Number, textColor as Number) as Void {
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h / 2, Graphics.FONT_TINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw a large gold/cost figure centred at (cx, y): the digits in one of
    //! Garmin's numeric faces, the magnitude suffix beside them in a text font.
    //!
    //! The FONT_NUMBER_* faces are digit-only. They carry 0-9 and a little
    //! punctuation and nothing else, so a letter drawn in one of them silently
    //! renders as nothing at all - which is why the main screen showed a pile
    //! of "1.23" where it meant "1.23M", while the crew screen, drawn in an
    //! ordinary text font, was right all along. Splitting the two halves keeps
    //! the tall numerals and still shows the magnitude.
    function bigValue(dc as Dc, cx as Number, y as Number, value as Double,
                      color as Number, numberFont as FontType) as Void {
        var p = Fmt.parts(value);
        var digits = p[0];
        var suffix = p[1];

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (suffix.equals("")) {
            dc.drawText(cx, y, numberFont, digits, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var suffixFont = Graphics.FONT_SMALL;
        var digitsW = dc.getTextWidthInPixels(digits, numberFont);
        var suffixW = dc.getTextWidthInPixels(suffix, suffixFont);
        var left = cx - (digitsW + GAP + suffixW) / 2;

        // Sit the suffix on the numerals' baseline rather than their box, so
        // the pair reads as one number instead of two stacked labels.
        var drop = baseline(dc, numberFont) - baseline(dc, suffixFont);

        dc.drawText(left, y, numberFont, digits, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(left + digitsW + GAP, y + drop, suffixFont, suffix,
            Graphics.TEXT_JUSTIFY_LEFT);
    }

    //! Pixels from the top of a font's line box down to its baseline.
    function baseline(dc as Dc, font as FontType) as Number {
        if (Graphics has :getFontAscent) {
            return Graphics.getFontAscent(font);
        }
        // Older devices only expose the full line height; its bottom is close
        // enough to the baseline for a two-part number to look aligned.
        return dc.getFontHeight(font);
    }

    //! Progress ring starting at 12 o'clock and sweeping clockwise.
    function ring(dc as Dc, cx as Number, cy as Number, radius as Number,
                  width as Number, progress as Float, color as Number) as Void {
        dc.setPenWidth(width);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (progress >= 0.999) {
            dc.drawCircle(cx, cy, radius);
        } else if (progress > 0.004) {
            var end = 90.0 - 360.0 * progress;
            while (end < 0.0) {
                end += 360.0;
            }
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, end.toNumber());
        }
        dc.setPenWidth(1);
    }

    //! Half-width of the round screen at a given distance from the centre.
    //! Used to keep text inside the glass instead of clipped by the bezel.
    function chordHalfWidth(radius as Number, dy as Number) as Number {
        var d = dy.abs();
        if (d >= radius) {
            return 0;
        }
        return Math.sqrt((radius * radius - d * d).toFloat()).toNumber();
    }
}
