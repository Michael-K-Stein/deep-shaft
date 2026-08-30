import Toybox.Lang;

//! All of the game's tuning lives here so the curve can be re-balanced without
//! touching the simulation or the views.
module Balance {

    //! Number of hireable crew types.
    const CREW_COUNT = 13;

    //! Every purchase of a crew member makes the next one 13% dearer. This is
    //! the classic idle-game escalation: cheap early, brutal late.
    const COST_GROWTH = 1.13d;

    //! Sticker price of the first unit of each crew type.
    const CREW_BASE_COST = [
        15.0d,
        130.0d,
        1500.0d,
        18000.0d,
        240000.0d,
        3600000.0d,
        60000000.0d,
        1100000000.0d,
        25000000000.0d,
        600000000000.0d,
        17000000000000.0d,
        520000000000000.0d,
        18000000000000000.0d
    ];

    //! Gold per second contributed by a single unit of each crew type.
    const CREW_BASE_RATE = [
        0.15d,
        1.2d,
        9.0d,
        70.0d,
        520.0d,
        4200.0d,
        38000.0d,
        380000.0d,
        4200000.0d,
        50000000.0d,
        650000000.0d,
        9100000000.0d,
        140000000000.0d
    ];

    //! A crew type stays hidden until the player has earned a fraction of its
    //! price, which keeps the shop short and readable on a small screen.
    const REVEAL_FRACTION = 0.30d;

    //! --- Depth -----------------------------------------------------------
    //! Digging deeper is the main gold sink. Cost climbs faster than the bonus
    //! so it stays a meaningful decision rather than an obvious auto-buy.
    const DEPTH_BASE_COST = 400.0d;
    const DEPTH_COST_GROWTH = 1.9d;
    const DEPTH_BONUS = 1.25d;
    const METRES_PER_LEVEL = 12;

    //! Ore layers, one per six depth levels, purely for flavour and colour.
    const LAYER_COUNT = 12;
    const LEVELS_PER_LAYER = 6;

    //! --- Milestones ------------------------------------------------------
    //! Every 25 units of a crew type doubles that type's output. This is the
    //! oldest trick in the genre and it earns its keep: it turns a flat "buy
    //! the best thing" shop into a ladder of near-term goals, so there is
    //! always a next reward in sight a few purchases away rather than one
    //! distant unlock. Because the cost of a unit grows 13% a step, a doubling
    //! every 25 steps roughly keeps pace instead of running away.
    const MILESTONE_EVERY = 25;
    const MILESTONE_MULT = 2.0d;

    //! --- Lucky strikes ----------------------------------------------------
    //! A glinting vein surfaces in the rock every couple of minutes and sits
    //! there for a few seconds. Tapping it pays out a burst of income.
    //!
    //! This is the reason to open the app rather than let it idle: idle games
    //! that only ever pay out on a timer give the player nothing to do when
    //! they arrive. The floor in swings keeps the very first strikes worth
    //! chasing, back when income per second is still a rounding error.
    const STRIKE_MIN_SECS = 75.0;
    const STRIKE_MAX_SECS = 210.0;
    const STRIKE_VISIBLE_SECS = 7.0;
    const STRIKE_REWARD_SECS = 25.0d;
    const STRIKE_MIN_SWINGS = 12.0d;

    //! --- Prestige --------------------------------------------------------
    //! "Detonate the mine": wipe the run, keep gems, each gem is +2% forever.
    //!
    //! The payout is logarithmic on purpose. Income in an idle game compounds
    //! twice over - more crew and a deeper shaft - so any power-law payout runs
    //! away: a four-hour session was worth 160,000 gems before this changed.
    //! A log curve still rewards a longer run, but with sharply diminishing
    //! returns, which keeps every prestige meaningful instead of the last one
    //! being the only one that mattered.
    const DETONATE_MIN_EARNED = 100000000.0d;   // 100M
    const DETONATE_REFERENCE = 10000000.0d;     // 10M
    const DETONATE_SCALE = 20.0d;
    const GEM_BONUS = 0.02d;

    //! --- Idle ------------------------------------------------------------
    //! The signature idle-game moment: come back later, find a pile of gold.
    const MAX_OFFLINE_SECS = 43200;             // 12 hours
    const OFFLINE_EFFICIENCY = 0.5d;
    const MIN_OFFLINE_SECS = 60;

    //! --- Tapping ---------------------------------------------------------
    //! A swing is always worth something, and scales with the crew so manual
    //! play never becomes pointless.
    const TAP_BASE = 1.0d;
    const TAP_RATE_SHARE = 0.10d;

    //! How often the simulation flushes to persistent storage, in seconds.
    const AUTOSAVE_SECS = 30;
}
