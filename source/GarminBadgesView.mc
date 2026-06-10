import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.WatchUi;

class GarminBadgesView extends ScrollableView {

    private var _loading    as Lang.Boolean = true;
    private var _error      as Lang.String  = "";
    private var _challenges as Lang.Array<Lang.Dictionary> = [];
    private var _upcoming   as Lang.Array<Lang.Dictionary> = [];

    function initialize() {
        ScrollableView.initialize();
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
            dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.06 + 0.5).toNumber(), Graphics.FONT_XTINY,
                "UPCOMING", justify);

            for (var i = 0; i < upcomingCount; i += 1) {
                var ub      = _upcoming[i] as Lang.Dictionary;
                var ubName  = ub.get("name");
                var ubDays  = ub.get("days_until");

                var ubNameStr = (ubName != null) ? ubName as Lang.String : "";
                var ubDaysNum = (ubDays != null) ? ubDays as Lang.Number : 0;

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
                dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, (rowTop + rowHeightPx / 2).toNumber(), Graphics.FONT_XTINY,
                    "MORE", justify);
                continue;
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
