import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Second page — all in-progress, time-limited challenges, sorted most
// urgent (most days behind schedule) first. Reached via the "MORE" row
// on GarminBadgesView.
class GarminBadgesAllChallengesView extends WatchUi.View {

    private var _challenges as Lang.Array<Lang.Dictionary>;

    private var _scrollOffset as Lang.Number = 0;
    private var _maxScroll    as Lang.Number = 0;

    private const ROW_HEIGHT_FRAC = 0.255;

    private const RED   = 0xe53935;
    private const GREEN = 0x43a047;
    private const GRAY  = 0x888888;
    private const DIM   = 0x444444;

    function initialize(challenges as Lang.Array<Lang.Dictionary>) {
        View.initialize();
        _challenges = challenges;
    }

    function onLayout(dc as Graphics.Dc) as Void {
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

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Title
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.08 + 0.5).toNumber(), Graphics.FONT_XTINY,
            "ALL CHALLENGES", justify);

        // Divider
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * 0.16).toNumber(),
                    (w * 0.85).toNumber(), (h * 0.16).toNumber());

        var viewportTop    = (h * 0.22).toNumber();
        var viewportHeight = h - viewportTop;

        if (_challenges.size() == 0) {
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, viewportTop + viewportHeight / 2, Graphics.FONT_SMALL,
                "No challenges\nin progress", justify);
            return;
        }

        var barLeft   = (w * 0.12).toNumber();
        var barRight  = (w * 0.88).toNumber();
        var barWidth  = barRight - barLeft;
        var barHeight = (h * 0.035 + 0.5).toNumber();

        var count         = _challenges.size();
        var rowHeightPx   = (h * ROW_HEIGHT_FRAC).toNumber();
        var contentHeight = count * rowHeightPx;

        _maxScroll = contentHeight - viewportHeight;
        if (_maxScroll < 0) {
            _maxScroll = 0;
        }
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }

        dc.setClip(0, viewportTop, w, viewportHeight);

        for (var i = 0; i < count; i += 1) {
            var badge = _challenges[i] as Lang.Dictionary;

            var name    = badge.get("name");
            var nameStr = (name != null) ? name as Lang.String : "";

            var progress   = badge.get("progress_value");
            var target     = badge.get("target_value");
            var unit       = badge.get("unit_key");
            var daysBehind = badge.get("days_behind");

            var progressVal   = toFloatVal(progress, 0.0);
            var targetVal     = toFloatVal(target, 0.0);
            var unitStr       = (unit != null) ? unit as Lang.String : "";
            var daysBehindVal = toFloatVal(daysBehind, 0.0);

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

            var rowTop = viewportTop + i * rowHeightPx - _scrollOffset;

            // Skip rows fully outside the viewport
            if (rowTop + rowHeightPx <= viewportTop || rowTop >= viewportTop + viewportHeight) {
                continue;
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

    private function trim(s as Lang.String, maxLen as Lang.Number) as Lang.String {
        if (s.length() > maxLen) {
            return s.substring(0, maxLen - 1) + "~";
        }
        return s;
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
