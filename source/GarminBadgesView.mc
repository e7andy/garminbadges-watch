import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

class GarminBadgesView extends ScrollableView {

    private var _loading    as Lang.Boolean = true;
    private var _hasData    as Lang.Boolean = false;
    private var _refreshing as Lang.Boolean = false;
    private var _error      as Lang.String  = "";
    private var _challenges as Lang.Array<Lang.Dictionary> = [];
    private var _upcoming   as Lang.Array<Lang.Dictionary> = [];

    private var _upcomingRowTop      as Lang.Number = 0;
    private var _upcomingRowHeight   as Lang.Number = 0;
    private var _upcomingCount       as Lang.Number = 0;
    private var _selectedUpcomingIdx as Lang.Number = -1;

    function initialize() {
        ScrollableView.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
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

        if (!_hasData) {
            _scrollOffset        = 0;
            _selectedUpcomingIdx = -1;
        }
        _hasData = true;
        _loading = false;
        _error   = "";
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

        var titleY   = 0.08;
        var dividerY = 0.16;
        var rowStart = 0.22;

        var upcomingCount = _upcoming.size();
        if (upcomingCount > 2) {
            upcomingCount = 2;
        }

        _upcomingCount = upcomingCount;

        if (upcomingCount > 0) {
            // "Upcoming" section
            dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.06 + 0.5).toNumber(), Graphics.FONT_XTINY,
                "UPCOMING", justify);

            _upcomingRowTop    = (h * 0.0975).toNumber();
            _upcomingRowHeight = (h * 0.065).toNumber();

            for (var i = 0; i < upcomingCount; i += 1) {
                var ub      = _upcoming[i] as Lang.Dictionary;
                var ubName  = ub.get("name");
                var ubDays  = ub.get("days_until");

                var ubNameStr = (ubName != null) ? ubName as Lang.String : "";
                var ubDaysNum = (ubDays != null) ? ubDays as Lang.Number : 0;

                if (_selectedUpcomingIdx == i) {
                    BadgeFormat.drawSelectionMarker(dc, _upcomingRowTop + i * _upcomingRowHeight, _upcomingRowHeight, w);
                }

                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (h * (0.13 + i * 0.065) + 0.5).toNumber(), Graphics.FONT_XTINY,
                    BadgeFormat.trim(ubNameStr, 16) + " " + BadgeFormat.formatDaysUntil(ubDaysNum), justify);
            }

            var afterUpcomingY = 0.13 + upcomingCount * 0.065;

            // Divider between sections
            dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawLine((w * 0.15).toNumber(), (h * (afterUpcomingY + 0.02)).toNumber(),
                        (w * 0.85).toNumber(), (h * (afterUpcomingY + 0.02)).toNumber());

            titleY   = afterUpcomingY + 0.07;
            dividerY = afterUpcomingY + 0.13;
            rowStart = afterUpcomingY + 0.19;
        }

        // "Challenges" title
        dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * titleY + 0.5).toNumber(), Graphics.FONT_XTINY,
            "CHALLENGES", justify);

        // Divider
        dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * dividerY).toNumber(),
                    (w * 0.85).toNumber(), (h * dividerY).toNumber());

        var viewportTop    = (h * rowStart).toNumber();
        var viewportHeight = h - viewportTop;

        if (_challenges.size() == 0) {
            var emptyFont = (upcomingCount > 0) ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, viewportTop + viewportHeight / 2, emptyFont,
                "No challenges\nin progress", justify);
            return;
        }

        var totalCount   = _challenges.size();
        var displayCount = totalCount;
        if (displayCount > 5) {
            displayCount = 5;
        }
        var hasMore = totalCount > 5;

        var rowHeightPx  = (h * ROW_HEIGHT_FRAC).toNumber();
        var totalRows    = displayCount + (hasMore ? 1 : 0);
        var contentHeight = totalRows * rowHeightPx;

        _viewportTop = viewportTop;
        _rowHeightPx = rowHeightPx;

        // Extra trailing space so the last row can be scrolled all the way
        // up to the top of the viewport (and thus become selectable).
        var extraSpace = viewportHeight - rowHeightPx;
        if (extraSpace < 0) {
            extraSpace = 0;
        }

        _maxScroll = contentHeight + extraSpace - viewportHeight;
        if (_maxScroll < 0) {
            _maxScroll = 0;
        }
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
        }

        var selectedIdx = rowIndexAt(viewportTop);

        dc.setClip(0, viewportTop, w, viewportHeight);

        for (var i = 0; i < totalRows; i += 1) {
            var rowTop = viewportTop + i * rowHeightPx - _scrollOffset;

            // Skip rows fully outside the viewport
            if (rowTop + rowHeightPx <= viewportTop || rowTop >= viewportTop + viewportHeight) {
                continue;
            }

            // "MORE" row
            if (i >= displayCount) {
                dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (rowTop + rowHeightPx / 2).toNumber(), Graphics.FONT_XTINY,
                    "MORE", justify);
                continue;
            }

            if (_selectedUpcomingIdx == -1 && i == selectedIdx) {
                BadgeFormat.drawSelectionMarker(dc, rowTop, rowHeightPx, w);
            }

            BadgeFormat.drawChallengeRow(dc, _challenges[i] as Lang.Dictionary, rowTop, w, h, justify);
        }

        dc.clearClip();

        BadgeFormat.drawScrollIndicator(dc, w, h, viewportTop, viewportHeight, contentHeight, _scrollOffset, _maxScroll);
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

    // Returns the challenge at screen y-coordinate, or null if y is on the
    // "MORE" row, outside the list, or there's no challenge there.
    function challengeAt(y as Lang.Number) as Lang.Dictionary? {
        var idx = rowIndexAt(y);
        if (idx < 0 || idx >= _challenges.size()) {
            return null;
        }

        var displayCount = _challenges.size();
        if (displayCount > 5) {
            displayCount = 5;
        }
        if (idx >= displayCount) {
            return null; // "MORE" row or beyond
        }

        return _challenges[idx] as Lang.Dictionary;
    }

    // True if the "MORE" row is at screen y-coordinate.
    function moreRowAt(y as Lang.Number) as Lang.Boolean {
        if (!hasMoreChallenges()) {
            return false;
        }

        var displayCount = 5;
        return rowIndexAt(y) == displayCount;
    }

    // Number of "UPCOMING" rows shown (0-2).
    function upcomingCount() as Lang.Number {
        return _upcomingCount;
    }

    // Index of the "UPCOMING" row currently selected via UP/DOWN, or -1 if
    // none (i.e. a challenge row is selected instead).
    function selectedUpcomingIndex() as Lang.Number {
        return _selectedUpcomingIdx;
    }

    function setSelectedUpcomingIndex(idx as Lang.Number) as Void {
        _selectedUpcomingIdx = idx;
    }

    // Returns the upcoming badge at the given index, or null if out of range.
    function upcomingBadgeAt(idx as Lang.Number) as Lang.Dictionary? {
        if (idx < 0 || idx >= _upcoming.size()) {
            return null;
        }
        return _upcoming[idx] as Lang.Dictionary;
    }

    // Returns the upcoming badge at screen y-coordinate, or null if y is
    // outside the "UPCOMING" rows.
    function upcomingAt(y as Lang.Number) as Lang.Dictionary? {
        if (_upcomingCount == 0 || y < _upcomingRowTop) {
            return null;
        }

        var idx = (y - _upcomingRowTop) / _upcomingRowHeight;
        if (idx < 0 || idx >= _upcomingCount) {
            return null;
        }

        return _upcoming[idx] as Lang.Dictionary;
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
