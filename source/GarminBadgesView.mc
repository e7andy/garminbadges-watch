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

    private const ROW_HEIGHT_FRAC = 0.255;

    private const RED   = 0xe53935;
    private const GREEN = 0x43a047;
    private const GRAY  = 0x888888;
    private const DIM   = 0x444444;

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

            var maxDuration = Application.Properties.getValue("MaxDurationDays") as Lang.Number?;
            if (maxDuration == null) {
                maxDuration = 0;
            }

            var ch = d.get("challenges");
            if (ch instanceof Lang.Array) {
                _challenges = filterByDuration(ch as Lang.Array<Lang.Dictionary>, maxDuration);
            } else {
                _challenges = [];
            }

            var up = d.get("upcoming");
            if (up instanceof Lang.Array) {
                _upcoming = filterByDuration(up as Lang.Array<Lang.Dictionary>, maxDuration);
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

        dc.setClip(0, viewportTop, w, viewportHeight);

        for (var i = 0; i < totalRows; i += 1) {
            var rowTop = viewportTop + i * rowHeightPx - _scrollOffset;

            // Skip rows fully outside the viewport
            if (rowTop + rowHeightPx <= viewportTop || rowTop >= viewportTop + viewportHeight) {
                continue;
            }

            // "MORE" row
            if (i >= displayCount) {
                dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (rowTop + rowHeightPx / 2).toNumber(), Graphics.FONT_XTINY,
                    "MORE", justify);
                continue;
            }

            var badge = _challenges[i] as Lang.Dictionary;

            var name    = badge.get("name");
            var nameStr = (name != null) ? name as Lang.String : "";

            var progress   = badge.get("progress_value");
            var target     = badge.get("target_value");
            var unit       = badge.get("unit_key");
            var daysBehind = badge.get("days_behind");

            var progressVal     = toFloatVal(progress, 0.0);
            var targetVal       = toFloatVal(target, 0.0);
            var unitStr         = (unit != null) ? unit as Lang.String : "";
            var daysBehindVal   = toFloatVal(daysBehind, 0.0);

            var hasTarget = targetVal > 0;
            var ratio = 0.0;
            if (hasTarget) {
                ratio = progressVal / targetVal;
                if (ratio > 1.0) {
                    ratio = 1.0;
                }
                if (ratio < 0.0) {
                    ratio = 0.0;
                }
            }

            var nameY = (rowTop + h * 0.045).toNumber();

            // Badge name (left)
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barLeft, nameY, Graphics.FONT_XTINY,
                trim(nameStr, 24), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Days ahead/behind schedule (right)
            var daysColor = GRAY;
            if (daysBehindVal >= 0.5) {
                daysColor = RED;
            } else if (daysBehindVal <= -0.5) {
                daysColor = GREEN;
            }
            dc.setColor(daysColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barRight, nameY, Graphics.FONT_XTINY,
                formatDaysOffset(daysBehindVal), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            if (hasTarget) {
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
            } else {
                // No numeric target (e.g. "finish in the top 3" challenges) — just
                // show the name/days row, no progress bar or fraction.
                dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (rowTop + h * 0.18 + 0.5).toNumber(), Graphics.FONT_XTINY,
                    "No target", justify);
            }
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

    // True when the list is scrolled all the way down to the "MORE" row.
    function atMoreRow() as Lang.Boolean {
        return hasMoreChallenges() && _maxScroll > 0 && _scrollOffset >= _maxScroll;
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

    // Drops items whose "duration_days" exceeds maxDays. maxDays <= 0 means
    // no limit (everything is kept).
    private function filterByDuration(items as Lang.Array<Lang.Dictionary>, maxDays as Lang.Number) as Lang.Array<Lang.Dictionary> {
        if (maxDays <= 0) {
            return items;
        }

        var result = [] as Lang.Array<Lang.Dictionary>;
        for (var i = 0; i < items.size(); i += 1) {
            var item = items[i] as Lang.Dictionary;
            var duration = item.get("duration_days");
            var durationVal = (duration != null) ? duration as Lang.Number : 0;
            if (durationVal <= maxDays) {
                result.add(item);
            }
        }
        return result;
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

    // Positive = behind schedule ("+Nd"), negative = ahead ("-Nd"), 0 = on track.
    private function formatDaysOffset(daysBehind as Lang.Float) as Lang.String {
        var rounded = -daysBehind.toNumber();
        if (rounded > 0) {
            return "+" + rounded.toString() + "d";
        }
        return rounded.toString() + "d";
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
