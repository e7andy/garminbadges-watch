import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Shared formatting helpers and challenge-row drawing for the main and
// all-challenges pages, which use the same row layout. Annotated (:glance)
// since GarminBadgesGlanceView (also (:glance)) uses several of these too.
(:glance)
module BadgeFormat {

    const RED       = 0xe53935;
    const GREEN     = 0x43a047;
    const GRAY      = 0x888888;
    const DIM       = 0x444444;
    const HIGHLIGHT = 0x2196f3;
    const TINT      = 0x1c2733;

    const MENU_ICON_SIZE_FRAC   = 0.045;
    const MENU_ICON_MARGIN_FRAC = 0.05;

    // Main-page section ids, in display order. A section is hidden entirely
    // when its item list is empty.
    const SECTION_UPCOMING    = 0;
    const SECTION_ENDING_SOON = 1;
    const SECTION_CHALLENGES  = 2;

    // Page-flip ticker timing, shared by views that show a ticker for text
    // too wide to fit (glance title, challenge/upcoming row names).
    const TICKER_TICK_MS      = 1000;
    const PAGE_DURATION_TICKS = 2;

    // Splits text on spaces. Lang.String has no split() in this API.
    function splitWords(text as Lang.String) as Lang.Array<Lang.String> {
        var words     = [] as Lang.Array<Lang.String>;
        var remaining = text;

        while (true) {
            var idx = remaining.find(" ");
            if (idx == null) {
                if (remaining.length() > 0) {
                    words.add(remaining);
                }
                break;
            }

            var word = remaining.substring(0, idx) as Lang.String;
            if (word.length() > 0) {
                words.add(word);
            }
            remaining = remaining.substring(idx + 1, remaining.length()) as Lang.String;
        }

        return words;
    }

    // Available text width (in pixels) at vertical position y. On
    // round/semi-round screens this is the chord width at y rather than the
    // full screen width, so wrapped text doesn't run under the bezel near
    // the top/bottom of the screen.
    function textMaxWidth(w as Lang.Number, h as Lang.Number, y as Lang.Number) as Lang.Number {
        var shape = System.getDeviceSettings().screenShape;
        if (shape != System.SCREEN_SHAPE_ROUND && shape != System.SCREEN_SHAPE_SEMI_ROUND) {
            return (w * 0.9).toNumber();
        }

        var radius = w / 2.0;
        var dy     = (y - h / 2.0).abs();
        if (dy >= radius) {
            return (w * 0.5).toNumber();
        }

        var chord = 2.0 * Math.sqrt(radius * radius - dy * dy);
        return (chord * 0.88).toNumber();
    }

    // Greedily groups whole words into lines, each line's pixel width
    // <= maxWidth.
    function wrapText(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, maxWidth as Lang.Number) as Lang.Array<Lang.String> {
        var words   = splitWords(text);
        var lines   = [] as Lang.Array<Lang.String>;
        var current = "";

        for (var i = 0; i < words.size(); i += 1) {
            var word      = words[i] as Lang.String;
            var candidate = current.equals("") ? word : current + " " + word;

            if (current.equals("") || dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                current = candidate;
            } else {
                lines.add(current);
                current = word;
            }
        }

        if (!current.equals("")) {
            lines.add(current);
        }
        if (lines.size() == 0) {
            lines.add(text);
        }

        return lines;
    }

    // Returns the text to draw this tick: `text` itself if it fits within
    // maxWidth, otherwise a page-flip ticker that cycles through whole-word
    // chunks, PAGE_DURATION_TICKS ticks per page, driven by tickCount (a
    // counter incremented once per TICKER_TICK_MS by the caller's timer).
    function pagedText(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, maxWidth as Lang.Number, tickCount as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var pages     = wrapText(dc, text, font, maxWidth);
        var pageIndex = (tickCount / PAGE_DURATION_TICKS) % pages.size();
        return pages[pageIndex] as Lang.String;
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

    // "Ends today" if daysUntilEnd <= 0 (including overdue), otherwise "Ends Nd".
    function formatEndsIn(daysUntilEnd as Lang.Number) as Lang.String {
        return (daysUntilEnd <= 0) ? "Ends today" : ("Ends " + daysUntilEnd.toString() + "d");
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

    // Draws the days-behind/ahead indicator (right) and the page-flip
    // ticker'd "name + nameSuffix" (left) on one line at lineY. Returns the
    // days-indicator color, which drawChallengeRow reuses for its progress
    // bar fill.
    function drawNameAndDaysLine(dc as Graphics.Dc, badge as Lang.Dictionary, lineY as Lang.Number, barLeft as Lang.Number, barRight as Lang.Number, w as Lang.Number, tickCount as Lang.Number, nameSuffix as Lang.String) as Lang.Number {
        var name    = badge.get("name");
        var nameStr = (name != null) ? name as Lang.String : "";

        var daysBehindVal = toFloatVal(badge.get("days_behind"), 0.0);

        // Days ahead/behind schedule (right)
        var daysColor = GRAY;
        if (daysBehindVal >= 0.5) {
            daysColor = RED;
        } else if (daysBehindVal <= -0.5) {
            daysColor = GREEN;
        }
        var daysText  = formatDaysOffset(daysBehindVal);
        var daysWidth = dc.getTextWidthInPixels(daysText, Graphics.FONT_XTINY);
        dc.setColor(daysColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barRight, lineY, Graphics.FONT_XTINY,
            daysText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Badge name + suffix (left) — page-flip ticker if too wide to fit
        // next to the days indicator
        var nameMaxWidth = barRight - barLeft - daysWidth - (w * 0.02).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barLeft, lineY, Graphics.FONT_XTINY,
            pagedText(dc, nameStr + nameSuffix, Graphics.FONT_XTINY, nameMaxWidth, tickCount), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        return daysColor;
    }

    // Draws a compact one-line row (name [+ nameSuffix] on the left,
    // days-behind/ahead indicator on the right), vertically centered within
    // rowHeight. Used for the ENDING SOON and CHALLENGES sections on the main
    // page.
    function drawCompactRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowTop as Lang.Number, rowHeight as Lang.Number, w as Lang.Number, tickCount as Lang.Number, nameSuffix as Lang.String) as Void {
        var lineY = (rowTop + rowHeight / 2).toNumber();
        drawNameAndDaysLine(dc, badge, lineY, (w * 0.12).toNumber(), (w * 0.88).toNumber(), w, tickCount, nameSuffix);
    }

    // Draws an "upcoming" row: badge name (left) + "Today"/"Nd" due date
    // (right), vertically centered at rowY. On round/semi-round screens,
    // falls back to a single centered line (name + due date) so rows near
    // the top/bottom of the screen don't run under the bezel.
    function drawUpcomingRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowY as Lang.Number, w as Lang.Number, h as Lang.Number, tickCount as Lang.Number) as Void {
        var name    = badge.get("name");
        var nameStr = (name != null) ? name as Lang.String : "";
        var due     = badge.get("days_until");
        var dueVal  = (due != null) ? due as Lang.Number : 0;
        var dueText = formatDaysUntil(dueVal);

        // Badges that started within the last 24h and aren't yet joined come
        // back as "Today" (days_until == 0) — highlight them in red so they
        // stand out from the "starts in Nd" rows.
        var isToday  = (dueVal == 0);
        var textColor = isToday ? RED : Graphics.COLOR_WHITE;
        var dueColor  = isToday ? RED : GRAY;

        var shape = System.getDeviceSettings().screenShape;
        if (shape == System.SCREEN_SHAPE_ROUND || shape == System.SCREEN_SHAPE_SEMI_ROUND) {
            var text     = nameStr + " " + dueText;
            var maxWidth = textMaxWidth(w, h, rowY);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, rowY, Graphics.FONT_XTINY,
                pagedText(dc, text, Graphics.FONT_XTINY, maxWidth, tickCount),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var barLeft  = (w * 0.12).toNumber();
        var barRight = (w * 0.88).toNumber();

        dc.setColor(dueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barRight, rowY, Graphics.FONT_XTINY,
            dueText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        var dueWidth     = dc.getTextWidthInPixels(dueText, Graphics.FONT_XTINY);
        var nameMaxWidth = barRight - barLeft - dueWidth - (w * 0.02).toNumber();
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barLeft, rowY, Graphics.FONT_XTINY,
            pagedText(dc, nameStr, Graphics.FONT_XTINY, nameMaxWidth, tickCount),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draws a section title (e.g. "UPCOMING") centered at fractional height y.
    function drawSectionTitle(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, y as Lang.Float, title as Lang.String) as Void {
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * y + 0.5).toNumber(), Graphics.FONT_XTINY,
            title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draws a horizontal divider line at fractional height y.
    function drawSectionDivider(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, y as Lang.Float) as Void {
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * y).toNumber(),
                    (w * 0.85).toNumber(), (h * y).toNumber());
    }

    // Draws one challenge row (name, days-offset, and progress bar/fraction or
    // "No target") at the given top y-coordinate. Shared by the main page and
    // the all-challenges/all-ending-soon pages, which use identical row layouts.
    function drawChallengeRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowTop as Lang.Number, w as Lang.Number, h as Lang.Number, justify as Lang.Number, tickCount as Lang.Number) as Void {
        var cx = w / 2;

        var barLeft   = (w * 0.12).toNumber();
        var barRight  = (w * 0.88).toNumber();
        var barWidth  = barRight - barLeft;
        var barHeight = (h * 0.035 + 0.5).toNumber();

        var progressVal = toFloatVal(badge.get("progress_value"), 0.0);
        var targetVal   = toFloatVal(badge.get("target_value"), 0.0);
        var unit        = badge.get("unit_key");
        var unitStr     = (unit != null) ? unit as Lang.String : "";

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
        var daysColor = drawNameAndDaysLine(dc, badge, nameY, barLeft, barRight, w, tickCount, "");

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

    // Draws a subtle background tint across a row, marking it as selected.
    function drawSelectionTint(dc as Graphics.Dc, rowTop as Lang.Number, rowHeight as Lang.Number, w as Lang.Number) as Void {
        dc.setColor(TINT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, rowTop, w, rowHeight);
    }

    // Draws a vertical accent bar on the left edge of a row, marking it as
    // the item that SELECT/tap will open the detail view for.
    function drawSelectionMarker(dc as Graphics.Dc, rowTop as Lang.Number, rowHeight as Lang.Number, w as Lang.Number) as Void {
        var barWidth = (w * 0.012 + 0.5).toNumber();
        if (barWidth < 2) {
            barWidth = 2;
        }
        dc.setColor(HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((w * 0.07).toNumber(), rowTop, barWidth, rowHeight);
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
