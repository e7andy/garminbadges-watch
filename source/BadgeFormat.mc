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

    // Marquee-scroll timing/speed, shared by every view that shows a
    // continuously-scrolling ticker for text too wide to fit (glance title,
    // challenge/upcoming row names). SCROLL_TICK_MS just drives how often a
    // view requests a redraw while a marquee might be animating — the
    // scroll position itself is computed from elapsed wall-clock time
    // (System.getTimer()), not a tick count, so it's correctly paced
    // whenever a redraw actually lands even where a device throttles
    // glance/view redraws below SCROLL_TICK_MS.
    const SCROLL_TICK_MS         = 50;
    const SCROLL_PAUSE_START_MS  = 900;
    const SCROLL_PAUSE_END_MS    = 500;
    const SCROLL_SPEED_PX_PER_SEC = 55.0;

    // Bundles the parameters every scrolling-text draw call needs, since
    // some older devices cap Monkey C functions at 9 parameters — passing
    // marked/nowMs/groupScrollMs/clipTop/clipHeight individually through
    // drawChallengeRow -> drawNameAndDaysLine -> drawScrollingText (etc.)
    // blew past that limit.
    //
    // marked: gates whether text scrolls at all (see drawScrollingText).
    // nowMs: a shared System.getTimer() value for every row drawn in one
    // frame/group, so they stay in sync.
    // groupScrollMs: > 0 makes sibling rows scroll in lockstep off the
    // longest row's duration; <= 0 means solo/self-paced.
    // clipTop/clipHeight: the (full-width) clip rectangle active on dc
    // before drawing, to restore after a tighter scroll-band clip; null for
    // both if no clip is active.
    class ScrollCtx {
        var marked as Lang.Boolean;
        var nowMs as Lang.Number;
        var groupScrollMs as Lang.Number;
        var clipTop as Lang.Number?;
        var clipHeight as Lang.Number?;

        function initialize(marked as Lang.Boolean, nowMs as Lang.Number, groupScrollMs as Lang.Number, clipTop as Lang.Number?, clipHeight as Lang.Number?) {
            self.marked        = marked;
            self.nowMs         = nowMs;
            self.groupScrollMs = groupScrollMs;
            self.clipTop       = clipTop;
            self.clipHeight    = clipHeight;
        }
    }

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

    // Pixel distance a scrolling marquee needs to travel to reveal the tail
    // end of `text` once (0 if it already fits in areaWidth) — it stops
    // there rather than scrolling the whole text away.
    function scrollDistancePx(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, areaWidth as Lang.Number) as Lang.Number {
        var distance = dc.getTextWidthInPixels(text, font) - areaWidth;
        return (distance > 0) ? distance : 0;
    }

    // Milliseconds needed to scroll scrollDistancePx() at SCROLL_SPEED_PX_PER_SEC.
    function scrollDurationMs(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, areaWidth as Lang.Number) as Lang.Number {
        return (scrollDistancePx(dc, text, font, areaWidth) / SCROLL_SPEED_PX_PER_SEC * 1000).toNumber();
    }

    // Draws `text` within a horizontal band of areaWidth pixels at
    // (areaLeft, lineY), vertically centered: as-is if it fits (per
    // fitJustify, LEFT or CENTER), otherwise as a marquee that pauses,
    // scrolls left just far enough to reveal the tail end once, holds
    // there, then loops back to the start — it never scrolls the text
    // fully away.
    //
    // ctx bundles marked/nowMs/groupScrollMs/clipTop/clipHeight — see
    // ScrollCtx.
    function drawScrollingText(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, areaLeft as Lang.Number, areaWidth as Lang.Number, lineY as Lang.Number, w as Lang.Number, fitJustify as Lang.Number, ctx as ScrollCtx) as Void {
        var vjustify  = Graphics.TEXT_JUSTIFY_VCENTER;
        var textWidth = dc.getTextWidthInPixels(text, font);

        if (textWidth <= areaWidth) {
            var fitX = (fitJustify == Graphics.TEXT_JUSTIFY_CENTER) ? areaLeft + areaWidth / 2 : areaLeft;
            dc.drawText(fitX, lineY, font, text, fitJustify | vjustify);
            return;
        }

        var distance = textWidth - areaWidth;
        var x = areaLeft;

        if (ctx.marked) {
            var scrollMs = (ctx.groupScrollMs > 0) ? ctx.groupScrollMs : (distance / SCROLL_SPEED_PX_PER_SEC * 1000).toNumber();
            var cycleMs  = SCROLL_PAUSE_START_MS + scrollMs + SCROLL_PAUSE_END_MS;
            var phase    = ctx.nowMs % cycleMs;

            if (phase < SCROLL_PAUSE_START_MS) {
                x = areaLeft;
            } else if (phase < SCROLL_PAUSE_START_MS + scrollMs) {
                var elapsedPx = (phase - SCROLL_PAUSE_START_MS) / 1000.0 * SCROLL_SPEED_PX_PER_SEC;
                if (elapsedPx > distance) {
                    elapsedPx = distance;
                }
                x = areaLeft - elapsedPx.toNumber();
            } else {
                x = areaLeft - distance;
            }
        }
        // else: unmarked — stays at areaLeft (static, showing just the head)

        var bandTop    = lineY - dc.getFontHeight(font) / 2 - 2;
        var bandBottom = lineY + dc.getFontHeight(font) / 2 + 2;
        var clipTop    = ctx.clipTop;
        var clipHeight = ctx.clipHeight;
        if (clipTop != null && clipHeight != null) {
            var outerTop    = clipTop as Lang.Number;
            var outerBottom = outerTop + (clipHeight as Lang.Number);
            if (bandTop < outerTop) {
                bandTop = outerTop;
            }
            if (bandBottom > outerBottom) {
                bandBottom = outerBottom;
            }
        }
        if (bandBottom <= bandTop) {
            return;
        }

        dc.setClip(areaLeft, bandTop, areaWidth, bandBottom - bandTop);
        dc.drawText(x, lineY, font, text, Graphics.TEXT_JUSTIFY_LEFT | vjustify);

        if (clipTop != null && clipHeight != null) {
            dc.setClip(0, clipTop as Lang.Number, w, clipHeight as Lang.Number);
        } else {
            dc.clearClip();
        }
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

    // The garminbadges.com detail-page URL for a badge dict, or null if it
    // has no "id" (e.g. stale cached data from before this field existed).
    function badgeUrl(badge as Lang.Dictionary) as Lang.String? {
        var id = badge.get("id");
        if (id == null) {
            return null;
        }
        return "https://garminbadges.com/badges/" + (id as Lang.Number).toString();
    }

    // FONT_SYSTEM_SMALL if the device's "Text Size" setting is scaled up
    // (DeviceSettings.fontScale, API 5.0.1+), otherwise FONT_SYSTEM_TINY.
    // Devices without fontScale always get FONT_SYSTEM_TINY.
    function glanceFont() as Graphics.FontDefinition {
        var settings = System.getDeviceSettings();
        if ((settings has :fontScale) && settings.fontScale != null && settings.fontScale > 1.0) {
            return Graphics.FONT_SYSTEM_SMALL;
        }
        return Graphics.FONT_SYSTEM_TINY;
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
    // mi_km/ft_m/yd_m, seconds for seconds) and formatted per-unit for display.
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

        if (unitStr.equals("yd_m")) {
            var statute = (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE);
            var factor  = statute ? 1.09361 : 1.0;
            var label   = statute ? "yd" : "m";
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

    function badgeName(badge as Lang.Dictionary) as Lang.String {
        var name = badge.get("name");
        return (name != null) ? name as Lang.String : "";
    }

    // The scrolling name text and its available width for a compact/
    // challenge row's name+days line — shared by drawNameAndDaysLine and
    // callers that need to measure a marked group's shared scroll duration
    // up front (see drawScrollingText's groupScrollMs).
    function nameLineTextAndWidth(dc as Graphics.Dc, badge as Lang.Dictionary, barLeft as Lang.Number, barRight as Lang.Number, w as Lang.Number, nameSuffix as Lang.String) as Lang.Array {
        var daysWidth = dc.getTextWidthInPixels(formatDaysOffset(toFloatVal(badge.get("days_behind"), 0.0)), glanceFont());
        var nameMaxWidth = barRight - barLeft - daysWidth - (w * 0.02).toNumber();
        return [badgeName(badge) + nameSuffix, nameMaxWidth];
    }

    // Draws the days-behind/ahead indicator (right) and the scrolling
    // "name + nameSuffix" (left) on one line at lineY. Returns the
    // days-indicator color, which drawChallengeRow reuses for its progress
    // bar fill. ctx: see ScrollCtx.
    function drawNameAndDaysLine(dc as Graphics.Dc, badge as Lang.Dictionary, lineY as Lang.Number, barLeft as Lang.Number, barRight as Lang.Number, w as Lang.Number, nameSuffix as Lang.String, ctx as ScrollCtx) as Lang.Number {
        var daysBehindVal = toFloatVal(badge.get("days_behind"), 0.0);

        // Days ahead/behind schedule (right)
        var daysColor = GRAY;
        if (daysBehindVal >= 0.5) {
            daysColor = RED;
        } else if (daysBehindVal <= -0.5) {
            daysColor = GREEN;
        }
        var daysText = formatDaysOffset(daysBehindVal);
        dc.setColor(daysColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barRight, lineY, glanceFont(),
            daysText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Badge name + suffix (left) — scrolls if too wide to fit next to
        // the days indicator
        var parts        = nameLineTextAndWidth(dc, badge, barLeft, barRight, w, nameSuffix);
        var nameText      = parts[0] as Lang.String;
        var nameMaxWidth  = parts[1] as Lang.Number;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawScrollingText(dc, nameText, glanceFont(), barLeft, nameMaxWidth, lineY, w,
            Graphics.TEXT_JUSTIFY_LEFT, ctx);

        return daysColor;
    }

    // Draws a compact one-line row (name [+ nameSuffix] on the left,
    // days-behind/ahead indicator on the right), vertically centered within
    // rowHeight. Used for the ENDING SOON and CHALLENGES sections on the main
    // page. ctx: see ScrollCtx.
    function drawCompactRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowTop as Lang.Number, rowHeight as Lang.Number, w as Lang.Number, nameSuffix as Lang.String, ctx as ScrollCtx) as Void {
        var lineY = (rowTop + rowHeight / 2).toNumber();
        drawNameAndDaysLine(dc, badge, lineY, (w * 0.12).toNumber(), (w * 0.88).toNumber(), w, nameSuffix, ctx);
    }

    // The scrolling text, its available width/left edge, and fit-justify for
    // an "upcoming" row at rowY — shared by drawUpcomingRow and callers that
    // need to measure a marked group's shared scroll duration up front (see
    // drawScrollingText's groupScrollMs). See drawUpcomingRow for the
    // round/semi-round vs. rectangular screen distinction.
    function upcomingRowLayout(dc as Graphics.Dc, badge as Lang.Dictionary, w as Lang.Number, h as Lang.Number, rowY as Lang.Number) as Lang.Array {
        var nameStr = badgeName(badge);
        var due     = badge.get("days_until");
        var dueVal  = (due != null) ? due as Lang.Number : 0;
        var dueText = formatDaysUntil(dueVal);

        var shape = System.getDeviceSettings().screenShape;
        if (shape == System.SCREEN_SHAPE_ROUND || shape == System.SCREEN_SHAPE_SEMI_ROUND) {
            var maxWidth = textMaxWidth(w, h, rowY);
            return [nameStr + " " + dueText, (w - maxWidth) / 2, maxWidth, Graphics.TEXT_JUSTIFY_CENTER];
        }

        var barLeft      = (w * 0.12).toNumber();
        var barRight     = (w * 0.88).toNumber();
        var dueWidth     = dc.getTextWidthInPixels(dueText, glanceFont());
        var nameMaxWidth = barRight - barLeft - dueWidth - (w * 0.02).toNumber();
        return [nameStr, barLeft, nameMaxWidth, Graphics.TEXT_JUSTIFY_LEFT];
    }

    // Draws an "upcoming" row: badge name (left) + "Today"/"Nd" due date
    // (right), vertically centered at rowY. On round/semi-round screens,
    // falls back to a single centered line (name + due date) so rows near
    // the top/bottom of the screen don't run under the bezel.
    // ctx: see ScrollCtx.
    function drawUpcomingRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowY as Lang.Number, w as Lang.Number, h as Lang.Number, ctx as ScrollCtx) as Void {
        var due       = badge.get("days_until");
        var dueVal    = (due != null) ? due as Lang.Number : 0;
        var isToday   = (dueVal == 0);
        var textColor = isToday ? RED : Graphics.COLOR_WHITE;

        var layout   = upcomingRowLayout(dc, badge, w, h, rowY);
        var text     = layout[0] as Lang.String;
        var areaLeft = layout[1] as Lang.Number;
        var areaWidth = layout[2] as Lang.Number;
        var fitJustify = layout[3] as Lang.Number;

        var shape = System.getDeviceSettings().screenShape;
        if (shape == System.SCREEN_SHAPE_ROUND || shape == System.SCREEN_SHAPE_SEMI_ROUND) {
            // days_until == 0 ("Today") is highlighted in red, though in
            // practice unreachable since upcoming badges always have a
            // future start_date.
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            drawScrollingText(dc, text, glanceFont(), areaLeft, areaWidth, rowY, w,
                fitJustify, ctx);
            return;
        }

        var dueColor = isToday ? RED : GRAY;
        var dueText  = formatDaysUntil(dueVal);
        var barRight = (w * 0.88).toNumber();

        dc.setColor(dueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barRight, rowY, glanceFont(),
            dueText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        drawScrollingText(dc, text, glanceFont(), areaLeft, areaWidth, rowY, w,
            fitJustify, ctx);
    }

    // Draws a section title (e.g. "UPCOMING") centered at fractional height y.
    function drawSectionTitle(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, y as Lang.Float, title as Lang.String) as Void {
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * y + 0.5).toNumber(), glanceFont(),
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
    function drawChallengeRow(dc as Graphics.Dc, badge as Lang.Dictionary, rowTop as Lang.Number, w as Lang.Number, h as Lang.Number, justify as Lang.Number, ctx as ScrollCtx) as Void {
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
        var daysColor = drawNameAndDaysLine(dc, badge, nameY, barLeft, barRight, w, "", ctx);

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
            dc.drawText(cx, (rowTop + h * 0.205 + 0.5).toNumber(), glanceFont(),
                formatFraction(progressVal, targetVal, unitStr), justify);
        } else {
            // No numeric target (e.g. "finish in the top 3" challenges) — just
            // show the name/days row, no progress bar or fraction.
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (rowTop + h * 0.18 + 0.5).toNumber(), glanceFont(),
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

    // Hourglass icon (two triangles pinched at the center), centered at
    // (cx, cy), used in place of the word "ending" in the glance summary.
    function drawHourglassIcon(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, size as Lang.Number, color as Lang.Number) as Void {
        var half = size / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - half, cy - half], [cx + half, cy - half], [cx, cy]]);
        dc.fillPolygon([[cx - half, cy + half], [cx + half, cy + half], [cx, cy]]);
    }

    // Downward-pointing triangle, centered at (cx, cy), used in place of the
    // word "behind" in the glance summary.
    function drawDownArrowIcon(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, size as Lang.Number, color as Lang.Number) as Void {
        var half = size / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - half, cy - half], [cx + half, cy - half], [cx, cy + half]]);
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
