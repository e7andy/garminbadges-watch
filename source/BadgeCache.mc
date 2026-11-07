import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

// Persists the latest /api/watch response so the main view and glance can
// show data immediately on launch while a fresh copy is fetched in the
// background. Annotated (:glance) since GarminBadgesGlanceView (also
// (:glance)) uses this too.
//
// The response holds day counts the server computed at fetch time
// (days_until_end, days_until, ...), so load() shifts them by the whole days
// elapsed since save() — otherwise stale data (e.g. watch offline for days)
// would keep showing "Ends 2d" forever.
(:glance)
module BadgeCache {

    const KEY          = "watchData";
    const SAVED_AT_KEY = "watchSavedAt";
    const SECONDS_PER_DAY = 86400;

    function load() as Lang.Dictionary? {
        var data = Storage.getValue(KEY);
        if (!(data instanceof Lang.Dictionary)) {
            return null;
        }
        var d = data as Lang.Dictionary;

        var savedAt = Storage.getValue(SAVED_AT_KEY);
        if (savedAt instanceof Lang.Number) {
            var days = (Time.now().value() - (savedAt as Lang.Number)) / SECONDS_PER_DAY;
            if (days > 0) {
                advance(d, days);
            }
        }
        return d;
    }

    function save(data as Lang.Dictionary) as Void {
        Storage.setValue(KEY, data);
        Storage.setValue(SAVED_AT_KEY, Time.now().value());
    }

    // Shifts the server-computed day counts forward by `days` whole days.
    function advance(d as Lang.Dictionary, days as Lang.Number) as Void {
        var ch = d.get("challenges");
        if (ch instanceof Lang.Array) {
            for (var i = 0; i < ch.size(); i += 1) {
                var c = ch[i] as Lang.Dictionary;

                var due = c.get("days_until_end");
                if (due instanceof Lang.Number) {
                    c.put("days_until_end", due - days);
                }

                // Not-yet-started challenges may have started by now.
                var started = c.get("started");
                var untilStart = c.get("days_until_start");
                if (started != null && !(started as Lang.Boolean) && untilStart instanceof Lang.Number) {
                    var left = untilStart - days;
                    if (left <= 0) {
                        c.put("started", true);
                        c.put("days_until_start", 0);
                    } else {
                        c.put("days_until_start", left);
                    }
                }

                // Progress is unchanged while the schedule moves on, so every
                // elapsed day makes a started challenge one day more behind
                // (capped at the challenge length).
                var behind = c.get("days_behind");
                var isStarted = (started == null) || (started as Lang.Boolean);
                if (isStarted && (behind instanceof Lang.Number || behind instanceof Lang.Float)) {
                    var shifted = behind + days;
                    var duration = c.get("duration_days");
                    if (duration instanceof Lang.Number && shifted > duration) {
                        shifted = (behind instanceof Lang.Float) ? duration.toFloat() : duration;
                    }
                    c.put("days_behind", shifted);
                }
            }
        }

        // Upcoming badges: count down; one whose start day has already
        // passed (more than a day ago) is no longer "upcoming".
        var up = d.get("upcoming");
        if (up instanceof Lang.Array) {
            var kept = [] as Lang.Array<Lang.Dictionary>;
            for (var i = 0; i < up.size(); i += 1) {
                var u = up[i] as Lang.Dictionary;
                var until = u.get("days_until");
                if (until instanceof Lang.Number) {
                    var left = until - days;
                    if (left < 0) {
                        continue;
                    }
                    u.put("days_until", left);
                }
                kept.add(u);
            }
            d.put("upcoming", kept);
        }
    }
}
