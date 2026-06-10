import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

class GarminBadgesView extends WatchUi.View {

    private var _loading  as Lang.Boolean = true;
    private var _error    as Lang.String  = "";
    private var _upcoming as Lang.Array<Lang.Dictionary> = [];

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

            var ub = d.get("upcoming_badges");
            if (ub instanceof Lang.Array) {
                _upcoming = ub as Lang.Array<Lang.Dictionary>;
            } else {
                _upcoming = [];
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
        dc.drawText(cx, (h * 0.08 + 0.5).toNumber(), Graphics.FONT_TINY,
            "UPCOMING BADGES", justify);

        // Divider
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * 0.16).toNumber(),
                    (w * 0.85).toNumber(), (h * 0.16).toNumber());

        if (_upcoming.size() == 0) {
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL,
                "No challenges\nin progress", justify);
            return;
        }

        var barLeft   = (w * 0.12).toNumber();
        var barRight  = (w * 0.88).toNumber();
        var barWidth  = barRight - barLeft;
        var barHeight = (h * 0.035 + 0.5).toNumber();

        var count = _upcoming.size();
        if (count > 3) {
            count = 3;
        }

        for (var i = 0; i < count; i += 1) {
            var badge = _upcoming[i] as Lang.Dictionary;

            var name    = badge.get("name");
            var nameStr = (name != null) ? name as Lang.String : "";

            var progress = badge.get("progress_value");
            var target   = badge.get("target_value");
            var unit     = badge.get("unit_key");

            var progressVal = (progress != null) ? progress as Lang.Float : 0.0;
            var targetVal   = (target != null) ? target as Lang.Float : 1.0;
            var unitStr     = (unit != null) ? unit as Lang.String : "";

            var ratio = progressVal / targetVal;
            if (ratio > 1.0) {
                ratio = 1.0;
            }
            if (ratio < 0.0) {
                ratio = 0.0;
            }

            var rowTop = h * 0.22 + i * h * 0.255;

            // Badge name
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (rowTop + h * 0.045).toNumber(), Graphics.FONT_XTINY,
                trim(nameStr, 22), justify);

            // Progress bar background
            var barTop = (rowTop + h * 0.105).toNumber();
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(barLeft, barTop, barWidth, barHeight);

            // Progress bar fill
            var fillWidth = (barWidth * ratio).toNumber();
            if (fillWidth > 0) {
                dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barLeft, barTop, fillWidth, barHeight);
            }

            // Fraction text
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            var fractionText = formatNum(progressVal) + "/" + formatNum(targetVal);
            if (!unitStr.equals("")) {
                fractionText += " " + unitStr;
            }
            dc.drawText(cx, (rowTop + h * 0.18 + 0.5).toNumber(), Graphics.FONT_XTINY,
                fractionText, justify);
        }
    }

    private function trim(s as Lang.String, maxLen as Lang.Number) as Lang.String {
        if (s.length() > maxLen) {
            return s.substring(0, maxLen - 1) + "~";
        }
        return s;
    }

    private function formatNum(value as Lang.Float) as Lang.String {
        if (value == value.toNumber().toFloat()) {
            return value.toNumber().toString();
        }
        return value.format("%.1f");
    }
}
