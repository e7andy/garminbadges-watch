import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Timer;
import Toybox.WatchUi;

// Glance preview shown in the widget glance loop. Selecting it (default
// GlanceViewDelegate behavior) opens the app's main view.
class GarminBadgesGlanceView extends WatchUi.GlanceView {

    private var _loading   as Lang.Boolean = true;
    private var _hasData   as Lang.Boolean = false;
    private var _error     as Lang.String  = "";
    private var _title     as Lang.String  = "";
    private var _endingSoon as Lang.Number = 0;
    private var _behind    as Lang.Number  = 0;
    private var _hasTarget as Lang.Boolean = false;
    private var _ratio     as Lang.Float   = 0.0;
    private var _barColor  as Lang.Number  = BadgeFormat.RED;

    private var _tickCount as Lang.Number = 0;
    private var _timer     as Timer.Timer?;

    function initialize() {
        GlanceView.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        var cached = BadgeCache.load();
        if (cached != null) {
            applyData(cached);
        }
        fetchData();

        if (_timer != null) {
            _timer.stop();
        }
        _tickCount = 0;
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), BadgeFormat.TICKER_TICK_MS, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        _tickCount += 1;
        WatchUi.requestUpdate();
    }

    function fetchData() as Void {
        var apiKey = Application.Properties.getValue("ApiKey") as Lang.String?;
        var apiUrl = Application.Properties.getValue("ApiUrl") as Lang.String?;

        if (apiKey == null || apiKey.equals("")) {
            _loading = false;
            _error   = "No API key";
            WatchUi.requestUpdate();
            return;
        }

        if (apiUrl == null || apiUrl.equals("")) {
            apiUrl = "https://api.garminbadges.com/api";
        }

        var options = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :headers      => {
                "Authorization" => "Bearer " + apiKey,
                "Accept"        => "application/json"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(apiUrl + "/watch", null, options, method(:onReceive));
    }

    function onReceive(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        _loading = false;

        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            var d = data as Lang.Dictionary;
            BadgeCache.save(d);
            applyData(d);
        } else if (!_hasData) {
            if (responseCode == 401) {
                _error = "Invalid API key";
            } else if (responseCode == -2) {
                _error = "No internet";
            } else {
                _error = "Error " + responseCode.toString();
            }
        }

        WatchUi.requestUpdate();
    }

    // Applies a /api/watch response (fresh or cached) to the glance state.
    private function applyData(d as Lang.Dictionary) as Void {
        var challenges = [] as Lang.Array<Lang.Dictionary>;
        var ch = d.get("challenges");
        if (ch instanceof Lang.Array) {
            challenges = ch as Lang.Array<Lang.Dictionary>;
        }

        var upcoming = [] as Lang.Array<Lang.Dictionary>;
        var up = d.get("upcoming");
        if (up instanceof Lang.Array) {
            upcoming = up as Lang.Array<Lang.Dictionary>;
        }

        _endingSoon = 0;
        _behind     = 0;
        for (var i = 0; i < challenges.size(); i += 1) {
            var c = challenges[i] as Lang.Dictionary;

            var db = c.get("days_behind");
            var dbVal = (db != null) ? db as Lang.Number : 0;
            if (dbVal > 0) {
                _behind += 1;
            }

            if (daysUntilEndOf(c) <= 7) {
                _endingSoon += 1;
            }
        }

        // Priority: the next badge to do — active today (started within the
        // last 24h, not yet joined) or starting within 7 days
        // (upcoming[0]); otherwise the most urgent challenge ending within 7
        // days; otherwise the most urgent challenge overall (challenges are
        // already sorted most-behind-first by the API).
        if (upcoming.size() > 0) {
            var u = upcoming[0] as Lang.Dictionary;
            var name = u.get("name");
            var nameStr = (name != null) ? name as Lang.String : "";

            var daysUntil = u.get("days_until");
            var daysUntilVal = (daysUntil != null) ? daysUntil as Lang.Number : 0;

            _title     = nameStr + " " + BadgeFormat.formatDaysUntil(daysUntilVal);
            _hasTarget = false;
            _ratio     = 0.0;
        } else {
            var endingSoon = findEndingSoon(challenges);
            if (endingSoon != null) {
                applyChallenge(endingSoon, " " + BadgeFormat.formatEndsIn(daysUntilEndOf(endingSoon)));
            } else if (challenges.size() > 0) {
                var c = challenges[0] as Lang.Dictionary;

                var suffix = "";
                var started = c.get("started");
                var startedVal = (started == null) || (started as Lang.Boolean);
                if (!startedVal) {
                    var daysUntilStart = c.get("days_until_start");
                    var daysUntilStartVal = (daysUntilStart != null) ? daysUntilStart as Lang.Number : 0;
                    suffix = " " + BadgeFormat.formatDaysUntil(daysUntilStartVal);
                }

                applyChallenge(c, suffix);
            } else {
                _title     = "No challenges";
                _hasTarget = false;
                _ratio     = 0.0;
            }
        }

        _hasData = true;
        _loading = false;
        _error   = "";
    }

    // days_until_end for a challenge, or 999 if missing (e.g. stale cache).
    private function daysUntilEndOf(badge as Lang.Dictionary) as Lang.Number {
        var due = badge.get("days_until_end");
        return (due != null) ? due as Lang.Number : 999;
    }

    // The challenge with the soonest days_until_end (<= 7), or null if none
    // qualify.
    private function findEndingSoon(challenges as Lang.Array<Lang.Dictionary>) as Lang.Dictionary? {
        var best = null;
        var bestDue = 999;
        for (var i = 0; i < challenges.size(); i += 1) {
            var c = challenges[i] as Lang.Dictionary;
            var due = daysUntilEndOf(c);
            if (due <= 7 && due < bestDue) {
                bestDue = due;
                best = c;
            }
        }
        return best;
    }

    // Sets _title (name + titleSuffix), _hasTarget, _ratio, and _barColor
    // from a challenge dictionary.
    private function applyChallenge(c as Lang.Dictionary, titleSuffix as Lang.String) as Void {
        var name = c.get("name");
        var nameStr = (name != null) ? name as Lang.String : "";
        _title = nameStr + titleSuffix;

        var targetVal = BadgeFormat.toFloatVal(c.get("target_value"), 0.0);
        if (targetVal > 0) {
            var progressVal = BadgeFormat.toFloatVal(c.get("progress_value"), 0.0);
            var ratio = progressVal / targetVal;
            if (ratio > 1.0) {
                ratio = 1.0;
            }
            if (ratio < 0.0) {
                ratio = 0.0;
            }
            _hasTarget = true;
            _ratio     = ratio;

            var daysBehindVal = BadgeFormat.toFloatVal(c.get("days_behind"), 0.0);
            if (daysBehindVal <= -0.5) {
                _barColor = BadgeFormat.GREEN;
            } else if (daysBehindVal >= 0.5) {
                _barColor = BadgeFormat.RED;
            } else {
                _barColor = BadgeFormat.GRAY;
            }
        } else {
            _hasTarget = false;
            _ratio     = 0.0;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var font    = BadgeFormat.glanceFont();

        if (_loading) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, font, "Loading...", justify);
            return;
        }

        if (!_error.equals("")) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, font, _error, justify);
            return;
        }

        // Line 1: title, page-flip ticker (alternating chunks of whole
        // words) if it doesn't fit
        var titleY = (h * 0.22).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, font, BadgeFormat.pagedText(dc, _title, font, w, _tickCount), justify);

        // Middle: progress bar for the closest challenge (empty if the
        // closest item is an upcoming badge or has no numeric target)
        var barLeft   = (w * 0.08).toNumber();
        var barWidth  = (w * 0.84).toNumber();
        var barTop    = (h * 0.42).toNumber();
        var barHeight = (h * 0.18).toNumber();

        dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barLeft, barTop, barWidth, barHeight);

        if (_hasTarget) {
            var fillWidth = (barWidth * _ratio).toNumber();
            if (fillWidth > 0) {
                dc.setColor(_barColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barLeft, barTop, fillWidth, barHeight);
            }
        }

        // Line 2: number of challenges ending soon and number behind schedule
        var summaryY    = (h * 0.78).toNumber();
        var summaryText = _endingSoon.toString() + " ending · " + _behind.toString() + " behind";

        dc.setColor((_behind > 0) ? BadgeFormat.RED : BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, summaryY, font, summaryText, justify);
    }
}
