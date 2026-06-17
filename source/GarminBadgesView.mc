import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

class GarminBadgesView extends ScrollableView {

    private const TOP_MARGIN_FRAC       = 0.05;
    private const TITLE_TO_DIVIDER_FRAC = 0.045;
    private const DIVIDER_TO_ROWS_FRAC  = 0.02;
    private const SECTION_GAP_FRAC      = 0.035;
    private const MAIN_ROW_HEIGHT_FRAC  = 0.07;

    private var _loading    as Lang.Boolean = true;
    private var _hasData    as Lang.Boolean = false;
    private var _refreshing as Lang.Boolean = false;
    private var _error      as Lang.String  = "";
    private var _challenges as Lang.Array<Lang.Dictionary> = [];
    private var _upcoming   as Lang.Array<Lang.Dictionary> = [];
    private var _endingSoon as Lang.Array<Lang.Dictionary> = [];

    // Visible sections (in display order) and the pixel y-bounds of each
    // section's row area, recomputed every onUpdate(). Used for UP/DOWN
    // selection highlighting and tap hit-testing.
    private var _sectionIds      as Lang.Array<Lang.Number> = [];
    private var _sectionTops     as Lang.Array<Lang.Number> = [];
    private var _sectionBottoms  as Lang.Array<Lang.Number> = [];
    private var _selectedSectionIdx as Lang.Number = 0;

    function initialize() {
        ScrollableView.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        ScrollableView.onShow();

        var cached = BadgeCache.load();
        if (cached != null) {
            applyData(cached);
        }
        fetchData(true);
    }

    // silent: when true, refreshes in the background without showing the
    // "Refreshing..." indicator (used for the automatic refresh on open).
    function fetchData(silent as Lang.Boolean) as Void {
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

        if (!_hasData) {
            _loading = true;
            _error   = "";
        } else if (!silent) {
            _refreshing = true;
        }
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
        _loading    = false;
        _refreshing = false;

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

    // Applies a /api/watch response (fresh or cached) to the view state.
    private function applyData(d as Lang.Dictionary) as Void {
        var maxDurationRaw = null;
        try {
            maxDurationRaw = Application.Properties.getValue("MaxDurationDays");
        } catch (e) {
            maxDurationRaw = null;
        }
        var maxDuration = (maxDurationRaw instanceof Lang.Number) ? maxDurationRaw : 0;

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

        _endingSoon = computeEndingSoon(_challenges);

        if (!_hasData) {
            _selectedSectionIdx = 0;
        }
        _hasData = true;
        _loading = false;
        _error   = "";
    }

    // Challenges ending within 7 days (including overdue), sorted soonest
    // first. May overlap with _challenges (a challenge can appear in both the
    // CHALLENGES and ENDING SOON sections).
    private function computeEndingSoon(challenges as Lang.Array<Lang.Dictionary>) as Lang.Array<Lang.Dictionary> {
        var result = [] as Lang.Array<Lang.Dictionary>;
        for (var i = 0; i < challenges.size(); i += 1) {
            var badge = challenges[i] as Lang.Dictionary;
            if (daysUntilEndOf(badge) <= 7) {
                result.add(badge);
            }
        }

        // Insertion sort ascending by days_until_end (small arrays, <= 20 items).
        for (var i = 1; i < result.size(); i += 1) {
            var current    = result[i] as Lang.Dictionary;
            var currentDue = daysUntilEndOf(current);
            var j = i - 1;
            while (j >= 0 && daysUntilEndOf(result[j] as Lang.Dictionary) > currentDue) {
                result[j + 1] = result[j];
                j -= 1;
            }
            result[j + 1] = current;
        }

        return result;
    }

    private function daysUntilEndOf(badge as Lang.Dictionary) as Lang.Number {
        var due = badge.get("days_until_end");
        return (due != null) ? due as Lang.Number : 999;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        BadgeFormat.drawMenuIcon(dc, w, h);

        if (_refreshing) {
            var iconBounds = BadgeFormat.menuIconBounds(w, h);
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(iconBounds[1], iconBounds[1] + iconBounds[2] / 2, Graphics.FONT_XTINY,
                "Refreshing...", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

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

        var upCount = _upcoming.size();
        if (upCount > 3) {
            upCount = 3;
        }

        var endCount = _endingSoon.size();
        if (endCount > 3) {
            endCount = 3;
        }

        var chalCount = _challenges.size();
        if (chalCount > 5) {
            chalCount = 5;
        }

        if (upCount == 0 && endCount == 0 && chalCount == 0) {
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, "No challenges\nin progress", justify);
            return;
        }

        var visibleCount = 0;
        if (upCount > 0)   { visibleCount += 1; }
        if (endCount > 0)  { visibleCount += 1; }
        if (chalCount > 0) { visibleCount += 1; }

        if (_selectedSectionIdx < 0) {
            _selectedSectionIdx = 0;
        }
        if (_selectedSectionIdx >= visibleCount) {
            _selectedSectionIdx = visibleCount - 1;
        }

        _sectionIds     = [];
        _sectionTops    = [];
        _sectionBottoms = [];

        var currentY = TOP_MARGIN_FRAC;

        if (upCount > 0) {
            currentY = drawUpcomingSection(dc, w, h, currentY, upCount);
        }
        if (endCount > 0) {
            currentY = drawCompactSection(dc, w, h, currentY, "ENDING SOON", _endingSoon, endCount, BadgeFormat.SECTION_ENDING_SOON, true);
        }
        if (chalCount > 0) {
            currentY = drawCompactSection(dc, w, h, currentY, "CHALLENGES", _challenges, chalCount, BadgeFormat.SECTION_CHALLENGES, false);
        }
    }

    // Draws the "UPCOMING" section (title + one drawUpcomingRow() per badge)
    // and returns the fractional y just below it (where the next section's
    // title should start).
    private function drawUpcomingSection(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, startY as Lang.Float, count as Lang.Number) as Lang.Float {
        var sectionIdx = _sectionIds.size();

        BadgeFormat.drawSectionTitle(dc, w, h, startY, "NEXT BADGES");
        BadgeFormat.drawSectionDivider(dc, w, h, startY + TITLE_TO_DIVIDER_FRAC);

        var rowsTopFrac  = startY + TITLE_TO_DIVIDER_FRAC + DIVIDER_TO_ROWS_FRAC;
        var rowHeightPx  = (h * MAIN_ROW_HEIGHT_FRAC).toNumber();
        var rowsTopPx    = (h * rowsTopFrac).toNumber();
        var rowsBottomPx = rowsTopPx + count * rowHeightPx;

        if (sectionIdx == _selectedSectionIdx) {
            BadgeFormat.drawSelectionTint(dc, rowsTopPx, rowsBottomPx - rowsTopPx, w);
            BadgeFormat.drawSelectionMarker(dc, rowsTopPx, rowsBottomPx - rowsTopPx, w);
        }

        for (var i = 0; i < count; i += 1) {
            var badge = _upcoming[i] as Lang.Dictionary;
            var rowY  = rowsTopPx + i * rowHeightPx + rowHeightPx / 2;
            BadgeFormat.drawUpcomingRow(dc, badge, rowY, w, h, _tickCount);
        }

        _sectionIds.add(BadgeFormat.SECTION_UPCOMING);
        _sectionTops.add(rowsTopPx);
        _sectionBottoms.add(rowsBottomPx);

        return rowsTopFrac + count * MAIN_ROW_HEIGHT_FRAC + SECTION_GAP_FRAC;
    }

    // Draws a compact section (ENDING SOON or CHALLENGES): title + divider,
    // then one BadgeFormat.drawCompactRow() per item. Returns the fractional
    // y just below it.
    private function drawCompactSection(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, startY as Lang.Float, title as Lang.String, items as Lang.Array<Lang.Dictionary>, count as Lang.Number, sectionId as Lang.Number, showEndsIn as Lang.Boolean) as Lang.Float {
        var sectionIdx = _sectionIds.size();

        BadgeFormat.drawSectionTitle(dc, w, h, startY, title);
        BadgeFormat.drawSectionDivider(dc, w, h, startY + TITLE_TO_DIVIDER_FRAC);

        var rowsTopFrac  = startY + TITLE_TO_DIVIDER_FRAC + DIVIDER_TO_ROWS_FRAC;
        var rowHeightPx  = (h * MAIN_ROW_HEIGHT_FRAC).toNumber();
        var rowsTopPx    = (h * rowsTopFrac).toNumber();
        var rowsBottomPx = rowsTopPx + count * rowHeightPx;

        if (sectionIdx == _selectedSectionIdx) {
            BadgeFormat.drawSelectionTint(dc, rowsTopPx, rowsBottomPx - rowsTopPx, w);
            BadgeFormat.drawSelectionMarker(dc, rowsTopPx, rowsBottomPx - rowsTopPx, w);
        }

        for (var i = 0; i < count; i += 1) {
            var badge  = items[i] as Lang.Dictionary;
            var rowTop = rowsTopPx + i * rowHeightPx;

            var suffix = "";
            if (showEndsIn) {
                suffix = " " + BadgeFormat.formatEndsIn(daysUntilEndOf(badge));
            }

            BadgeFormat.drawCompactRow(dc, badge, rowTop, rowHeightPx, w, _tickCount, suffix);
        }

        _sectionIds.add(sectionId);
        _sectionTops.add(rowsTopPx);
        _sectionBottoms.add(rowsBottomPx);

        return rowsTopFrac + count * MAIN_ROW_HEIGHT_FRAC + SECTION_GAP_FRAC;
    }

    // Section id (SECTION_UPCOMING/ENDING_SOON/CHALLENGES) whose row area
    // contains screen y-coordinate, or -1 if none.
    function sectionAt(y as Lang.Number) as Lang.Number {
        for (var i = 0; i < _sectionIds.size(); i += 1) {
            if (y >= _sectionTops[i] && y < _sectionBottoms[i]) {
                return _sectionIds[i] as Lang.Number;
            }
        }
        return -1;
    }

    // The section id currently highlighted via UP/DOWN, or -1 if there are
    // no visible sections.
    function selectedSection() as Lang.Number {
        if (_selectedSectionIdx < 0 || _selectedSectionIdx >= _sectionIds.size()) {
            return -1;
        }
        return _sectionIds[_selectedSectionIdx] as Lang.Number;
    }

    // Moves the section selection by delta (UP = -1, DOWN = +1), clamped to
    // the visible sections.
    function moveSelection(delta as Lang.Number) as Void {
        var newIdx = _selectedSectionIdx + delta;
        if (newIdx < 0) {
            newIdx = 0;
        }
        if (newIdx >= _sectionIds.size()) {
            newIdx = _sectionIds.size() - 1;
        }
        _selectedSectionIdx = newIdx;
    }

    // Push the "all upcoming" page (next 10 upcoming badges).
    function showAllUpcoming() as Void {
        var view     = new GarminBadgesAllUpcomingView(_upcoming);
        var delegate = new GarminBadgesAllUpcomingDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    // Push the "all ending soon" page (challenges ending within 7 days).
    function showAllEndingSoon() as Void {
        var view     = new GarminBadgesAllEndingSoonView(_endingSoon);
        var delegate = new GarminBadgesAllEndingSoonDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    // Push the "all challenges" page, sorted most-urgent first.
    function showAllChallenges() as Void {
        var view     = new GarminBadgesAllChallengesView(_challenges);
        var delegate = new GarminBadgesAllChallengesDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
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
}
