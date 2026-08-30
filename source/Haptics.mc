import Toybox.Lang;

//! Vibration feedback, guarded twice: the Attention module is optional on some
//! products, and vibrate() is optional within it.
module Haptics {

    function pulse(strength as Number, durationMs as Number) as Void {
        var state = DeepShaftApp.game();
        if (state == null || !state.haptics) {
            return;
        }
        if (!(Toybox has :Attention)) {
            return;
        }
        if (!(Toybox.Attention has :vibrate)) {
            return;
        }
        Toybox.Attention.vibrate([
            new Toybox.Attention.VibeProfile(strength, durationMs)
        ] as Array<Toybox.Attention.VibeProfile>);
    }

    //! A single crisp tick for a swing.
    function tap() as Void {
        pulse(20, 30);
    }

    //! Confirmation for a purchase or a dig.
    function confirm() as Void {
        pulse(45, 60);
    }

    //! The mine going up.
    function boom() as Void {
        pulse(100, 400);
    }
}
