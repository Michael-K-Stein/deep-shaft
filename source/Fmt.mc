import Toybox.Lang;
import Toybox.Math;

//! Presentation helpers. Idle games live or die on how readable a very large
//! number is at a glance, so everything is squeezed to three significant
//! digits plus a short magnitude suffix.
module Fmt {

    //! Suffixes for 10^3 .. 10^45. Beyond that the game is over anyway.
    const SUFFIX = [
        "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
        "Ud", "Dd", "Td", "Qd"
    ];

    //! Split a value into its digits and its magnitude suffix, e.g.
    //! 1234567.0 -> ["1.23", "M"]. Amounts below 1000 come back with an empty
    //! suffix.
    //!
    //! The two halves are kept separate because Garmin's FONT_NUMBER_* faces
    //! are digit-only - see Theme.bigValue().
    function parts(value as Double) as Array<String> {
        var v = value;
        if (v < 0.0d) {
            v = 0.0d;
        }
        if (v < 1000.0d) {
            // Small amounts read better as whole numbers.
            return [v.toNumber().toString(), ""] as Array<String>;
        }

        var tier = 0;
        var last = SUFFIX.size() - 1;
        while (v >= 1000.0d && tier < last) {
            v /= 1000.0d;
            tier += 1;
        }

        var text;
        if (v < 10.0d) {
            text = v.format("%.2f");
        } else if (v < 100.0d) {
            text = v.format("%.1f");
        } else {
            text = v.format("%.0f");
        }
        return [text, (SUFFIX as Array<String>)[tier]] as Array<String>;
    }

    //! Format a currency-style amount, e.g. 1234567.0 -> "1.23M".
    function big(value as Double) as String {
        var p = parts(value);
        return p[0] + p[1];
    }

    //! Same as big(), but keeps one decimal for sub-1000 rates so that a slow
    //! early game still shows movement.
    function rate(value as Double) as String {
        if (value > 0.0d && value < 100.0d) {
            return value.format("%.1f");
        }
        return big(value);
    }

    //! "3h 12m", "12m 05s", "48s" - compact enough for the welcome-back card.
    function duration(seconds as Number) as String {
        var s = seconds;
        if (s < 0) {
            s = 0;
        }
        var h = s / 3600;
        var m = (s % 3600) / 60;
        var sec = s % 60;
        if (h > 0) {
            return h.toString() + "h " + m.format("%02d") + "m";
        }
        if (m > 0) {
            return m.toString() + "m " + sec.format("%02d") + "s";
        }
        return sec.toString() + "s";
    }

    //! Multiplier badge, e.g. "x3.8".
    function mult(value as Double) as String {
        if (value < 10.0d) {
            return "x" + value.format("%.2f");
        }
        if (value < 1000.0d) {
            return "x" + value.format("%.0f");
        }
        return "x" + big(value);
    }
}
