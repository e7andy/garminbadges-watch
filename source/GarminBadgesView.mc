import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.WatchUi;

class GarminBadgesView extends WatchUi.View {

    private var _loading    as Lang.Boolean = true;
    private var _error      as Lang.String  = "";
    private var _challenges as Lang.Array<Lang.Dictionary> = [];
    private var _upcoming   as Lang.Array<Lang.Dictionary> = [];

    private var _scrollOffset as Lang.Number = 0;
    private var _maxScroll    as Lang.Number = 0;

    // Bounds (screen px) of the "MORE" row when visible, for tap detection.
    // -1 when not currently shown/visible.
    private var _moreTop    as Lang.Number = -1;
    private var _moreBottom as Lang.Number = -1;

    private const ROW_HEIGHT_FRAC = 0.255;

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

    function scrollBy(deltaPx as Lang.Number) as Void {
        _scrollOffset += deltaPx;
        if (_scrollOffset < 0) {
            _scrollOffset = 0;
        }
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }
        WatchUi.requestUpdate();
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

            var ch = d.get("challenges");
            if (ch instanceof Lang.Array) {
                _challenges = ch as Lang.Array<Lang.Dictionary>;
            } else {
                _challenges = [];
            }

            var up = d.get("upcoming");
            if (up instanceof Lang.Array) {
                _upcoming = up as Lang.Array<Lang.Dictionary>;
            } else {
                _upcoming = [];
            }

            _scrollOffset = 0;
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

        var titleY   = 0.08;
        var dividerY = 0.16;
        var rowStart = 0.22;

        var upcomingCount = _upcoming.size();
        if (upcomingCount > 2) {
            upcomingCount = 2;
        }

        if (upcomingCount > 0) {
            // "Upcoming" section
            dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.06 + 0.5).toNumber(), Graphics.FONT_XTINY,
                "UPCOMING", justify);

            for (var i = 0; i < upcomingCount; i += 1) {
                var ub      = _upcoming[i] as Lang.Dictionary;
                var ubName  = ub.get("name");
                var ubDays  = ub.get("days_until");

                var ubNameStr = (ubName != null) ? ubName as Lang.String : "";
                var ubDaysNum = (ubDays != null) ? ubDays as Lang.Number : 0;
                var ubDaysStr = (ubDaysNum <= 0) ? "Today" : (ubDaysNum.toString() + "d");

                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (h * (0.13 + i * 0.065) + 0.5).toNumber(), Graphics.FONT_XTINY,
                    trim(ubNameStr, 16) + " " + ubDaysStr, justify);
            }

            var afterUpcomingY = 0.13 + upcomingCount * 0.065;

            // Divider between sections
            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawLine((w * 0.15).toNumber(), (h * (afterUpcomingY + 0.02)).toNumber(),
                        (w * 0.85).toNumber(), (h * (afterUpcomingY + 0.02)).toNumber());

            titleY   = afterUpcomingY + 0.07;
            dividerY = afterUpcomingY + 0.13;
            rowStart = afterUpcomingY + 0.19;
        }

        // "Challenges" title
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * titleY + 0.5).toNumber(), Graphics.FONT_XTINY,
            "CHALLENGES", justify);

        // Divider
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * dividerY).toNumber(),
                    (w * 0.85).toNumber(), (h * dividerY).toNumber());

        var viewportTop    = (h * rowStart).toNumber();
        var viewportHeight = h - viewportTop;

        if (_challenges.size() == 0) {
            var emptyFont = (upcomingCount > 0) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, viewportTop + viewportHeight / 2, emptyFont,
                "No challenges\nin progress", justify);
            return;
        }

        var barLeft   = (w * 0.12).toNumber();
        var barRight  = (w * 0.88).toNumber();
        var barWidth  = barRight - barLeft;
        var barHeight = (h * 0.035 + 0.5).toNumber();

        var totalCount   = _challenges.size();
        var displayCount = totalCount;
        if (displayCount > 5) {
            displayCount = 5;
        }
        var hasMore = totalCount > 5;

        var rowHeightPx  = (h * ROW_HEIGHT_FRAC).toNumber();
        var totalRows    = displayCount + (hasMore ? 1 : 0);
        var contentHeight = totalRows * rowHeightPx;

        _maxScroll = contentHeight - viewportHeight;
        if (_maxScroll < 0) {
            _maxScroll = 0;
        }
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }

        _moreTop    = -1;
        _moreBottom = -1;

        dc.setClip(0, viewportTop, w, viewportHeight);

        for (var i = 0; i < totalRows; i += 1) {
            var rowTop = viewportTop + i * rowHeightPx - _scrollOffset;

            // Skip rows fully outside the viewport
            if (rowTop + rowHeightPx <= viewportTop || rowTop >= viewportTop + viewportHeight) {
                continue;
            }

            // "MORE" row
            if (i >= displayCount) {
                _moreTop    = rowTop;
                _moreBottom = rowTop + rowHeightPx;

                dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (rowTop + rowHeightPx / 2).toNumber(), Graphics.FONT_XTINY,
                    "MORE ▸", justify);
                continue;
            }

            var badge = _challenges[i] as Lang.Dictionary;

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
            dc.drawText(cx, (rowTop + h * 0.18 + 0.5).toNumber(), Graphics.FONT_XTINY,
                formatFraction(progressVal, targetVal, unitStr), justify);
        }

        dc.clearClip();

        // Scroll indicator
        if (_maxScroll > 0) {
            var trackX      = (w * 0.965).toNumber();
            var thumbHeight = (viewportHeight.toFloat() * viewportHeight / contentHeight).toNumber();
            if (thumbHeight < (h * 0.04).toNumber()) {
                thumbHeight = (h * 0.04).toNumber();
            }
            var thumbY = viewportTop + (((viewportHeight - thumbHeight).toFloat() * _scrollOffset / _maxScroll)).toNumber();

            dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(trackX, thumbY, (w * 0.015 + 0.5).toNumber(), thumbHeight, 2);
        }
    }

    // True once the catalogue has more in-progress challenges than fit on the
    // main page (i.e. the "MORE" row is shown).
    function hasMoreChallenges() as Lang.Boolean {
        return _challenges.size() > 5;
    }

    // True if (x, y) falls within the currently-visible "MORE" row.
    function isMoreTap(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        return _moreTop >= 0 && y >= _moreTop && y < _moreBottom;
    }

    // Push the "all challenges" page, sorted most-urgent first.
    function showAllChallenges() as Void {
        var view     = new GarminBadgesAllChallengesView(_challenges);
        var delegate = new GarminBadgesAllChallengesDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
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

    // progressVal/targetVal are in the badge's raw storage units (meters for
    // mi_km, seconds for seconds) and formatted per-unit for display.
    private function formatFraction(progressVal as Lang.Float, targetVal as Lang.Float, unitStr as Lang.String) as Lang.String {
        if (unitStr.equals("mi_km")) {
            var statute = (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
            var factor  = statute ? 0.000621371 : 0.001;
            var label   = statute ? "mi" : "km";
            return formatNum(progressVal * factor) + "/" + formatNum(targetVal * factor) + " " + label;
        }

        if (unitStr.equals("ft_m")) {
            var statute = (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
            var factor  = statute ? 3.28084 : 1.0;
            var label   = statute ? "ft" : "m";
            return formatNum(progressVal * factor) + "/" + formatNum(targetVal * factor) + " " + label;
        }

        if (unitStr.equals("seconds")) {
            return formatTime(progressVal) + "/" + formatTime(targetVal);
        }

        if (unitStr.equals("kilocalories")) {
            return formatNum(progressVal) + "/" + formatNum(targetVal) + " kcal";
        }

        var text = formatNum(progressVal) + "/" + formatNum(targetVal);
        if (!unitStr.equals("")) {
            text += " " + unitStr;
        }
        return text;
    }

    // Whole hours show as "Nh"; otherwise "hh:mm:ss"
    private function formatTime(seconds as Lang.Float) as Lang.String {
        var total = seconds.toNumber();

        if (total % 3600 == 0) {
            return (total / 3600).toString() + "h";
        }

        var h = total / 3600;
        var m = (total % 3600) / 60;
        var s = total % 60;

        return h.format("%02d") + ":" + m.format("%02d") + ":" + s.format("%02d");
    }
}
