import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

class GarminBadgesView extends WatchUi.View {

    private var _loading    as Lang.Boolean = true;
    private var _error      as Lang.String  = "";
    private var _streak     as Lang.Number  = 0;
    private var _earnsYear  as Lang.Number  = 0;
    private var _pointsYear as Lang.Number  = 0;
    private var _recentBadge    as Lang.String = "";
    private var _challengeText  as Lang.String = "";

    private const RED  = 0xe53935;
    private const GRAY = 0x888888;
    private const DIM  = 0x444444;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        fetchData();
    }

    function fetchData() as Void {
        var apiKey = Application.Properties.getValue("ApiKey") as Lang.String?;
        var apiUrl = Application.Properties.getValue("ApiUrl") as Lang.String?;

        if (apiKey == null || apiKey.equals("")) {
            _loading = false;
            _error   = "Open Garmin Connect\napp to set API key";
            WatchUi.requestUpdate();
            return;
        }

        if (apiUrl == null || apiUrl.equals("")) {
            apiUrl = "https://api.garminbadges.com/api";
        }

        _loading = true;
        _error   = "";
        WatchUi.requestUpdate();

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

            var streak = d.get("current_streak");
            _streak = (streak != null) ? streak as Lang.Number : 0;

            var earns = d.get("earns_this_year");
            _earnsYear = (earns != null) ? earns as Lang.Number : 0;

            var pts = d.get("points_this_year");
            _pointsYear = (pts != null) ? pts as Lang.Number : 0;

            var rb = d.get("recent_badge");
            if (rb instanceof Lang.Dictionary) {
                var name = (rb as Lang.Dictionary).get("name");
                _recentBadge = (name != null) ? name as Lang.String : "";
            } else {
                _recentBadge = "";
            }

            var ch = d.get("top_challenge");
            if (ch instanceof Lang.Dictionary) {
                var chd  = ch as Lang.Dictionary;
                var name = chd.get("name");
                var prog = chd.get("progress_value");
                var tgt  = chd.get("target_value");
                if (name != null && prog != null && tgt != null) {
                    var progNum = (prog as Lang.Float).toNumber();
                    var tgtNum  = (tgt as Lang.Float).toNumber();
                    _challengeText = trim(name as Lang.String, 16) + " " + progNum + "/" + tgtNum;
                } else {
                    _challengeText = "";
                }
            } else {
                _challengeText = "";
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
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_loading) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_MEDIUM, "Loading...",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (!_error.equals("")) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, _error,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Title
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.10 + 0.5).toNumber(), Graphics.FONT_TINY,
            "GARMIN BADGES", justify);

        // Streak — hero number
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.31 + 0.5).toNumber(), Graphics.FONT_NUMBER_MEDIUM,
            _streak.toString(), justify);

        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.44 + 0.5).toNumber(), Graphics.FONT_XTINY,
            "DAY STREAK", justify);

        // Divider
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * 0.52).toNumber(),
                    (w * 0.85).toNumber(), (h * 0.52).toNumber());

        // Earns + Points (side by side)
        var lx = (w * 0.28 + 0.5).toNumber();
        var rx = (w * 0.72 + 0.5).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, (h * 0.62 + 0.5).toNumber(), Graphics.FONT_NUMBER_MILD,
            _earnsYear.toString(), justify);
        dc.drawText(rx, (h * 0.62 + 0.5).toNumber(), Graphics.FONT_NUMBER_MILD,
            _pointsYear.toString(), justify);

        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, (h * 0.71 + 0.5).toNumber(), Graphics.FONT_XTINY, "EARNS",  justify);
        dc.drawText(rx, (h * 0.71 + 0.5).toNumber(), Graphics.FONT_XTINY, "POINTS", justify);

        // Most recent badge
        if (!_recentBadge.equals("")) {
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.82 + 0.5).toNumber(), Graphics.FONT_TINY,
                trim(_recentBadge, 22), justify);
        }

        // Top challenge
        if (!_challengeText.equals("")) {
            dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.91 + 0.5).toNumber(), Graphics.FONT_XTINY,
                _challengeText, justify);
        }
    }

    private function trim(s as Lang.String, maxLen as Lang.Number) as Lang.String {
        if (s.length() > maxLen) {
            return s.substring(0, maxLen - 1) + "~";
        }
        return s;
    }
}
