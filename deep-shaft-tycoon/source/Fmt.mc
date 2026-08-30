import Toybox.Lang;

//! Short number formatting. Idle games live and die on legible big numbers, and
//! a 416px round screen has room for about six characters of cash.
module Fmt {

    var SUFFIX as Array<String> = [
        "", "K", "M", "B", "T", "q", "Q", "s", "S", "o", "N", "d", "U", "D"
    ];

    //! "$1.24M"
    function money(value as Numeric) as String {
        return "$" + big(value);
    }

    //! "1.24M", "938", "12.4K"
    function big(value as Numeric) as String {
        var v = value.toDouble();
        if (v < 0.0d) {
            return "-" + big(-v);
        }
        if (v < 1000.0d) {
            return plain(v);
        }
        var tier = 0;
        var last = SUFFIX.size() - 1;
        while (v >= 1000.0d && tier < last) {
            v /= 1000.0d;
            tier++;
        }
        if (v >= 1000.0d) {
            // Beyond the suffix table - fall back to scientific-ish notation.
            return v.format("%.0f") + SUFFIX[last];
        }
        return scaled(v) + SUFFIX[tier];
    }

    //! Mantissa with a sensible number of digits: 1.24 / 12.4 / 124
    function scaled(v as Double) as String {
        if (v < 10.0d) {
            return v.format("%.2f");
        }
        if (v < 100.0d) {
            return v.format("%.1f");
        }
        return v.format("%.0f");
    }

    //! Values below 1000, where cents only matter while you are still poor.
    function plain(v as Double) as String {
        if (v < 10.0d) {
            return v.format("%.1f");
        }
        return v.format("%.0f");
    }

    //! "1.2K/s"
    function rate(value as Numeric) as String {
        return big(value) + "/s";
    }

    //! Compact duration for cooldowns and offline time: 4h 12m / 3m 05s / 12s
    function duration(seconds as Numeric) as String {
        var s = seconds.toNumber();
        if (s < 0) {
            s = 0;
        }
        if (s >= 3600) {
            var h = s / 3600;
            var m = (s % 3600) / 60;
            return h.format("%d") + "h " + m.format("%02d") + "m";
        }
        if (s >= 60) {
            var m2 = s / 60;
            var s2 = s % 60;
            return m2.format("%d") + "m " + s2.format("%02d") + "s";
        }
        return s.format("%d") + "s";
    }
}
