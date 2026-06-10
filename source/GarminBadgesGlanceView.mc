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
    private var _error     as Lang.String  = "";
    private var _title     as Lang.String  = "";
    private var _behind    as Lang.Number  = 0;
    private var _hasTarget as Lang.Boolean = false;
    private var _ratio     as Lang.Float   = 0.0;

    private var _scrollX as Lang.Number = 0;
    private var _timer   as Timer.Timer?;

    private const RED  = 0xe53935;
    private const GRAY = 0x888888;
    private const DIM  = 0x444444;

    private const SCROLL_STEP_PX = 6;
    private const SCROLL_GAP_PX  = 30;

    function initialize() {
        GlanceView.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        fetchData();
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        _scrollX += SCROLL_STEP_PX;
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

            _behind = 0;
            for (var i = 0; i < challenges.size(); i += 1) {
                var c = challenges[i] as Lang.Dictionary;
                var db = c.get("days_behind");
                var dbVal = (db != null) ? db as Lang.Number : 0;
                if (dbVal > 0) {
                    _behind += 1;
                }
            }

            // Closest upcoming badge takes priority (it's the "next thing
            // coming up"); otherwise fall back to the most urgent challenge
            // (challenges are already sorted most-behind-first by the API).
            if (upcoming.size() > 0) {
                var u = upcoming[0] as Lang.Dictionary;
                var name = u.get("name");
                _title     = (name != null) ? name as Lang.String : "";
                _hasTarget = false;
                _ratio     = 0.0;
            } else if (challenges.size() > 0) {
                var c = challenges[0] as Lang.Dictionary;
                var name = c.get("name");
                _title = (name != null) ? name as Lang.String : "";

                var targetVal = toFloatVal(c.get("target_value"), 0.0);
                if (targetVal > 0) {
                    var progressVal = toFloatVal(c.get("progress_value"), 0.0);
                    var ratio = progressVal / targetVal;
                    if (ratio > 1.0) {
                        ratio = 1.0;
                    }
                    if (ratio < 0.0) {
                        ratio = 0.0;
                    }
                    _hasTarget = true;
                    _ratio     = ratio;
                } else {
                    _hasTarget = false;
                    _ratio     = 0.0;
                }
            } else {
                _title     = "No challenges";
                _hasTarget = false;
                _ratio     = 0.0;
            }

            _error = "";

        } else if (responseCode == 401) {
            _error = "Invalid API key";
        } else if (responseCode == -2) {
            _error = "No internet";
        } else {
            _error = "Error " + responseCode.toString();
        }

        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var font    = Graphics.FONT_XTINY;

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

        // Line 1: title, scrolling marquee if it doesn't fit
        var titleY    = (h * 0.22).toNumber();
        var textWidth = dc.getTextWidthInPixels(_title, font);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (textWidth <= w) {
            dc.drawText(w / 2, titleY, font, _title, justify);
        } else {
            var period = textWidth + SCROLL_GAP_PX;
            var x      = -(_scrollX % period);

            dc.setClip(0, 0, w, (h * 0.45).toNumber());
            dc.drawText(x, titleY, font, _title,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(x + period, titleY, font, _title,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.clearClip();
        }

        // Middle: progress bar for the closest challenge (empty if the
        // closest item is an upcoming badge or has no numeric target)
        var barLeft   = (w * 0.08).toNumber();
        var barWidth  = (w * 0.84).toNumber();
        var barTop    = (h * 0.42).toNumber();
        var barHeight = (h * 0.18).toNumber();

        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barLeft, barTop, barWidth, barHeight);

        if (_hasTarget) {
            var fillWidth = (barWidth * _ratio).toNumber();
            if (fillWidth > 0) {
                dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barLeft, barTop, fillWidth, barHeight);
            }
        }

        // Line 2: number of challenges behind schedule
        var behindY    = (h * 0.78).toNumber();
        var behindText = _behind.toString() + " behind";

        dc.setColor((_behind > 0) ? RED : GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, behindY, font, behindText, justify);
    }

    // JSON numbers without a fractional part decode as Lang.Number, and some
    // decimals decode as Lang.Double rather than Lang.Float — convert
    // explicitly so arithmetic doesn't truncate or fall through to default.
    private function toFloatVal(value as Lang.Object?, defaultVal as Lang.Float) as Lang.Float {
        if (value instanceof Lang.Float) {
            return value as Lang.Float;
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toFloat();
        }
        if (value instanceof Lang.Number) {
            return (value as Lang.Number).toFloat();
        }
        if (value instanceof Lang.Long) {
            return (value as Lang.Long).toFloat();
        }
        return defaultVal;
    }
}
