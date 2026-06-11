import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Shared formatting helpers and challenge-row drawing for the main and
// all-challenges pages, which use the same row layout.
module BadgeFormat {

    const RED   = 0xe53935;
    const GREEN = 0x43a047;
    const GRAY  = 0x888888;
    const DIM   = 0x444444;

    const MENU_ICON_SIZE_FRAC   = 0.045;
    const MENU_ICON_MARGIN_FRAC = 0.05;

    function trim(s as Lang.String, maxLen as Lang.Number) as Lang.String {
        if (s.length() > maxLen) {
            return s.substring(0, maxLen - 1) + "~";
        }
        return s;
    }

    // JSON numbers without a fractional part decode as Lang.Number, and some
    // decimals decode as Lang.Double rather than Lang.Float — convert
    // explicitly so arithmetic doesn't truncate or fall through to default.
    function toFloatVal(value as Lang.Object?, defaultVal as Lang.Float) as Lang.Float {
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

    // FONT_SYSTEM_TINY if the device's "Text Size" setting is scaled up
    // (DeviceSettings.fontScale, API 5.0.1+), otherwise FONT_SYSTEM_XTINY.
    // Devices without fontScale always get FONT_SYSTEM_XTINY.
    function glanceFont() as Graphics.FontDefinition {
        var settings = System.getDeviceSettings();
        if ((settings has :fontScale) && settings.fontScale != null && settings.fontScale > 1.0) {
            return Graphics.FONT_SYSTEM_TINY;
        }
        return Graphics.FONT_SYSTEM_XTINY;
    }

    // "Today" if daysUntil <= 0, otherwise "Nd".
    function formatDaysUntil(daysUntil as Lang.Number) as Lang.String {
        return (daysUntil <= 0) ? "Today" : (daysUntil.toString() + "d");
    }

    // Positive = behind schedule ("+Nd"), negative = ahead ("-Nd"), 0 = on track.
    function formatDaysOffset(daysBehind as Lang.Float) as Lang.String {
        var rounded = -daysBehind.toNumber();
        if (rounded > 0) {
            return "+" + rounded.toString() + "d";
        }
        return rounded.toString() + "d";
    }

    function formatNum(value as Lang.Float) as Lang.String {
        if (value == value.toNumber().toFloat()) {
            return value.toNumber().toString();
        }
        return value.format("%.1f");
    }

    // progressVal/targetVal are in the badge's raw storage units (meters for
    // mi_km, seconds for seconds) and formatted per-unit for display.
    function formatFraction(progressVal as Lang.Float, targetVal as Lang.Float, unitStr as Lang.String) as Lang.String {
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
    function formatTime(seconds as Lang.Float) as Lang.String {
        var total = seconds.toNumber();

        if (total % 3600 == 0) {
            return (total / 3600).toString() + "h";
        }

        var h = total / 3600;
        var m = (total % 3600) / 60;
        var s = total % 60;

        return h.format("%02d") + ":" + m.format("%02d") + ":" + s.format("%02d");
    }

    // Draws one challenge row (name, days-offset, and progress bar/fraction or
    // "No target") at the given top y-coordinate. Shared by the main page and
    // the all-challenges page, which use identical row layouts.
    function drawChallengeRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowTop as Lang.Number, w as Lang.Number, h as Lang.Number, justify as Lang.Number) as Void {
        var cx = w / 2;

        var barLeft   = (w * 0.12).toNumber();
        var barRight  = (w * 0.88).toNumber();
        var barWidth  = barRight - barLeft;
        var barHeight = (h * 0.035 + 0.5).toNumber();

        var name    = badge.get("name");
        var nameStr = (name != null) ? name as Lang.String : "";

        var progressVal   = toFloatVal(badge.get("progress_value"), 0.0);
        var targetVal     = toFloatVal(badge.get("target_value"), 0.0);
        var unit          = badge.get("unit_key");
        var unitStr       = (unit != null) ? unit as Lang.String : "";
        var daysBehindVal = toFloatVal(badge.get("days_behind"), 0.0);

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
                dc.setColor(daysColor, Graphics.COLOR_TRANSPARENT);
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

    // Top-left x/y and size (square) of the menu icon's tap target, in the
    // top-right corner of the screen.
    function menuIconBounds(w as Lang.Number, h as Lang.Number) as Lang.Array<Lang.Number> {
        var size   = (h * MENU_ICON_SIZE_FRAC).toNumber();
        var margin = (w * MENU_ICON_MARGIN_FRAC).toNumber();
        return [w - margin - size, margin, size];
    }

    // Draws a small "hamburger" icon in the top-right corner, marking that an
    // options menu is available (tap it, hold START/STOP, or press MENU).
    function drawMenuIcon(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var bounds = menuIconBounds(w, h);
        var x    = bounds[0];
        var y    = bounds[1];
        var size = bounds[2];
        var gap  = size / 3;

        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i += 1) {
            var ly = y + i * gap;
            dc.drawLine(x, ly, x + size, ly);
        }
    }

    // True if (x, y) falls within the menu icon's tap target, with extra
    // padding around it for easier touch.
    function isMenuIconHit(x as Lang.Number, y as Lang.Number, w as Lang.Number, h as Lang.Number) as Lang.Boolean {
        var bounds = menuIconBounds(w, h);
        var pad    = bounds[2];
        return x >= bounds[0] - pad && x <= bounds[0] + bounds[2] + pad &&
               y >= bounds[1] - pad && y <= bounds[1] + bounds[2] + pad;
    }

    // Draws the vertical scroll-position thumb on the right edge, if the
    // content overflows the viewport (maxScroll > 0).
    function drawScrollIndicator(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, viewportTop as Lang.Number, viewportHeight as Lang.Number, contentHeight as Lang.Number, scrollOffset as Lang.Number, maxScroll as Lang.Number) as Void {
        if (maxScroll <= 0) {
            return;
        }

        var trackX      = (w * 0.965).toNumber();
        var thumbHeight = (viewportHeight.toFloat() * viewportHeight / contentHeight).toNumber();
        if (thumbHeight < (h * 0.04).toNumber()) {
            thumbHeight = (h * 0.04).toNumber();
        }
        var thumbY = viewportTop + (((viewportHeight - thumbHeight).toFloat() * scrollOffset / maxScroll)).toNumber();

        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(trackX, thumbY, (w * 0.015 + 0.5).toNumber(), thumbHeight, 2);
    }
}
