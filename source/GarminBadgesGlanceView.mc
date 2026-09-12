import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Glance preview shown in the widget glance loop. Selecting it (default
// GlanceViewDelegate behavior) opens the app's main view.
//
// Annotated (:glance) so the compiler builds a separate, smaller binary for
// glance mode that excludes the main-app-only views/delegates (GarminBadgesView,
// the "All <Section>" pages, detail pages, etc.) — devices with a 32KB glance
// memory limit (e.g. Instinct 2/2X/3 Solar) otherwise OOM trying to load the
// entire app as the glance.
(:glance)
class GarminBadgesGlanceView extends WatchUi.GlanceView {

    // Title scroll phase (timing/speed shared via BadgeFormat.SCROLL_*).
    // Driven by elapsed wall-clock time (System.getTimer()) rather than a
    // tick count, so the scroll position is correct for whenever a redraw
    // actually lands even if the device throttles/coalesces glance redraws
    // below BadgeFormat.SCROLL_TICK_MS (not every device supports fast
    // "live update" glance redraws).
    private const SCROLL_PHASE_PAUSE_START = 0;
    private const SCROLL_PHASE_SCROLLING   = 1;
    private const SCROLL_PHASE_PAUSE_END   = 2;

    private var _loading   as Lang.Boolean = true;
    private var _hasData   as Lang.Boolean = false;
    private var _error     as Lang.String  = "";
    private var _title     as Lang.String  = "";
    private var _endingSoon as Lang.Number = 0;
    private var _behind    as Lang.Number  = 0;
    private var _hasTarget as Lang.Boolean = false;
    private var _ratio     as Lang.Float   = 0.0;
    private var _barColor  as Lang.Number  = BadgeFormat.RED;

    private var _timer     as Timer.Timer?;

    // Scroll state for the title line, keyed off the title text so a
    // refresh that changes the title restarts the scroll cleanly.
    private var _scrollText as Lang.String = "";
    private var _scrollPhase as Lang.Number = SCROLL_PHASE_PAUSE_START;
    private var _scrollPhaseStartMs as Lang.Number = 0;
    private var _scrollX as Lang.Float = 0.0;

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
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), BadgeFormat.SCROLL_TICK_MS, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
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

            if (startedOf(c) && daysUntilEndOf(c) <= 7) {
                _endingSoon += 1;
            }
        }

        // Priority: the most urgent challenge ending within 7 days; otherwise
        // the next badge starting within 7 days (upcoming[0]); otherwise the
        // most urgent challenge overall (challenges are already sorted
        // most-behind-first by the API).
        var endingSoon = findEndingSoon(challenges);
        if (endingSoon != null) {
            applyChallenge(endingSoon, " " + BadgeFormat.formatEndsIn(daysUntilEndOf(endingSoon)));
        } else if (upcoming.size() > 0) {
            var u = upcoming[0] as Lang.Dictionary;
            var name = u.get("name");
            var nameStr = (name != null) ? name as Lang.String : "";

            var daysUntil = u.get("days_until");
            var daysUntilVal = (daysUntil != null) ? daysUntil as Lang.Number : 0;

            _title     = nameStr + " " + BadgeFormat.formatDaysUntil(daysUntilVal);
            _hasTarget = false;
            _ratio     = 0.0;
        } else if (challenges.size() > 0) {
            var c = challenges[0] as Lang.Dictionary;

            var suffix = "";
            if (!startedOf(c)) {
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

        _hasData = true;
        _loading = false;
        _error   = "";
    }

    // days_until_end for a challenge, or 999 if missing (e.g. stale cache).
    private function daysUntilEndOf(badge as Lang.Dictionary) as Lang.Number {
        var due = badge.get("days_until_end");
        return (due != null) ? due as Lang.Number : 999;
    }

    // Missing/null "started" (e.g. stale cache from before the field
    // existed) defaults to true.
    private function startedOf(badge as Lang.Dictionary) as Lang.Boolean {
        var started = badge.get("started");
        return (started == null) || (started as Lang.Boolean);
    }

    // The started challenge with the soonest days_until_end (<= 7), or null
    // if none qualify.
    private function findEndingSoon(challenges as Lang.Array<Lang.Dictionary>) as Lang.Dictionary? {
        var best = null;
        var bestDue = 999;
        for (var i = 0; i < challenges.size(); i += 1) {
            var c = challenges[i] as Lang.Dictionary;
            var due = daysUntilEndOf(c);
            if (startedOf(c) && due <= 7 && due < bestDue) {
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

        // Line 1: title, continuous marquee scroll if it doesn't fit
        var titleY = (h * 0.22).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawScrollingTitle(dc, _title, font, w, titleY);

        // Middle: progress bar for the closest challenge (empty if the
        // closest item is an upcoming badge or has no numeric target)
        var barLeft   = (w * 0.08).toNumber();
        var barWidth  = (w * 0.84).toNumber();
        var barTop    = (h * 0.46).toNumber();
        var barHeight = (h * 0.10).toNumber();

        dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barLeft, barTop, barWidth, barHeight);

        if (_hasTarget) {
            var fillWidth = (barWidth * _ratio).toNumber();
            if (fillWidth > 0) {
                dc.setColor(_barColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barLeft, barTop, fillWidth, barHeight);
            }
        }

        // Line 2: number of challenges ending soon (hourglass icon) and
        // number behind schedule (down-arrow icon), each grayed out when
        // its count is zero
        var summaryY = (h * 0.78).toNumber();

        var iconSize = dc.getFontHeight(font) / 2;
        var iconGap  = (w * 0.035).toNumber();

        var endingNumStr   = _endingSoon.toString();
        var separatorPart  = " · ";
        var behindNumStr   = _behind.toString();

        var endingNumWidth = dc.getTextWidthInPixels(endingNumStr, font);
        var separatorWidth = dc.getTextWidthInPixels(separatorPart, font);
        var behindNumWidth = dc.getTextWidthInPixels(behindNumStr, font);
        var totalWidth     = iconSize + iconGap + endingNumWidth + separatorWidth +
                              iconSize + iconGap + behindNumWidth;

        var leftJustify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var x = (w - totalWidth) / 2;

        var endingColor = (_endingSoon > 0) ? BadgeFormat.RED : BadgeFormat.GRAY;
        BadgeFormat.drawHourglassIcon(dc, x + iconSize / 2, summaryY, iconSize, endingColor);
        x += iconSize + iconGap;

        dc.setColor(endingColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, summaryY, font, endingNumStr, leftJustify);
        x += endingNumWidth;

        dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, summaryY, font, separatorPart, leftJustify);
        x += separatorWidth;

        var behindColor = (_behind > 0) ? BadgeFormat.RED : BadgeFormat.GRAY;
        BadgeFormat.drawDownArrowIcon(dc, x + iconSize / 2, summaryY, iconSize, behindColor);
        x += iconSize + iconGap;

        dc.setColor(behindColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, summaryY, font, behindNumStr, leftJustify);
    }

    // Draws the title centered if it fits, otherwise as a continuously
    // scrolling marquee: pause, scroll left just far enough to reveal the
    // tail end once, hold there, then loop back to the start — it never
    // scrolls the title fully away. Position is computed from elapsed
    // wall-clock time (System.getTimer()) rather than ticks, so it's
    // correctly paced regardless of how often the device actually redraws
    // the glance.
    private function drawScrollingTitle(dc as Graphics.Dc, text as Lang.String, font as Graphics.FontDefinition, w as Lang.Number, y as Lang.Number) as Void {
        var textWidth = dc.getTextWidthInPixels(text, font);

        if (textWidth <= w) {
            _scrollText = "";
            dc.drawText(w / 2, y, font, text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var distance = textWidth - w;
        var now      = System.getTimer();

        if (!text.equals(_scrollText)) {
            _scrollText         = text;
            _scrollPhase        = SCROLL_PHASE_PAUSE_START;
            _scrollPhaseStartMs = now;
            _scrollX            = 0.0;
        }

        var elapsed = now - _scrollPhaseStartMs;
        if (elapsed < 0) {
            // System.getTimer() wrapped around; restart this phase cleanly.
            _scrollPhaseStartMs = now;
            elapsed = 0;
        }

        if (_scrollPhase == SCROLL_PHASE_PAUSE_START) {
            _scrollX = 0.0;
            if (elapsed >= BadgeFormat.SCROLL_PAUSE_START_MS) {
                _scrollPhase        = SCROLL_PHASE_SCROLLING;
                _scrollPhaseStartMs = now;
            }
        } else if (_scrollPhase == SCROLL_PHASE_SCROLLING) {
            _scrollX = 0.0 - (elapsed.toFloat() / 1000.0) * BadgeFormat.SCROLL_SPEED_PX_PER_SEC;
            if (_scrollX <= -distance) {
                _scrollX            = -distance.toFloat();
                _scrollPhase        = SCROLL_PHASE_PAUSE_END;
                _scrollPhaseStartMs = now;
            }
        } else {
            // SCROLL_PHASE_PAUSE_END: holding at the fully-revealed position.
            if (elapsed >= BadgeFormat.SCROLL_PAUSE_END_MS) {
                _scrollPhase        = SCROLL_PHASE_PAUSE_START;
                _scrollPhaseStartMs = now;
                _scrollX            = 0.0;
            }
        }

        dc.drawText(_scrollX.toNumber(), y, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
