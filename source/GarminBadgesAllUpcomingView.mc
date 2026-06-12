import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// "All Upcoming" page — the next (up to 10) badges starting within 7 days,
// sorted soonest-first. Reached by selecting/tapping the UPCOMING section on
// the main page.
class GarminBadgesAllUpcomingView extends ScrollableView {

    private var _upcoming as Lang.Array<Lang.Dictionary>;

    private const ALL_ROW_HEIGHT_FRAC = 0.12;

    function initialize(upcoming as Lang.Array<Lang.Dictionary>) {
        ScrollableView.initialize();
        _upcoming = upcoming;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Title — "NEXT UPCOMING" rather than "ALL UPCOMING" since the API
        // caps this list at the next 10, not the full set.
        dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.08 + 0.5).toNumber(), Graphics.FONT_XTINY,
            "NEXT UPCOMING", justify);

        // Divider
        dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.15).toNumber(), (h * 0.16).toNumber(),
                    (w * 0.85).toNumber(), (h * 0.16).toNumber());

        var viewportTop    = (h * 0.22).toNumber();
        var viewportHeight = h - viewportTop;

        if (_upcoming.size() == 0) {
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, viewportTop + viewportHeight / 2, Graphics.FONT_SMALL,
                "Nothing\nupcoming", justify);
            return;
        }

        var count         = _upcoming.size();
        var rowHeightPx   = (h * ALL_ROW_HEIGHT_FRAC).toNumber();
        var contentHeight = count * rowHeightPx;

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

        for (var i = 0; i < count; i += 1) {
            var rowTop = viewportTop + i * rowHeightPx - _scrollOffset;

            // Skip rows fully outside the viewport
            if (rowTop + rowHeightPx <= viewportTop || rowTop >= viewportTop + viewportHeight) {
                continue;
            }

            if (i == selectedIdx) {
                BadgeFormat.drawSelectionTint(dc, rowTop, rowHeightPx, w);
                BadgeFormat.drawSelectionMarker(dc, rowTop, rowHeightPx, w);
            }

            var badge = _upcoming[i] as Lang.Dictionary;
            var rowY  = rowTop + rowHeightPx / 2;
            BadgeFormat.drawUpcomingRow(dc, badge, rowY, w, h, _tickCount);
        }

        dc.clearClip();

        BadgeFormat.drawScrollIndicator(dc, w, h, viewportTop, viewportHeight, contentHeight, _scrollOffset, _maxScroll);
    }

    // Returns the upcoming badge at screen y-coordinate, or null if y is
    // outside the list.
    function upcomingAt(y as Lang.Number) as Lang.Dictionary? {
        var idx = rowIndexAt(y);
        if (idx < 0 || idx >= _upcoming.size()) {
            return null;
        }
        return _upcoming[idx] as Lang.Dictionary;
    }
}
