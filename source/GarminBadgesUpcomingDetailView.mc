import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Detail page for an upcoming badge — pushed when an "UPCOMING" row is
// selected on the main page. MENU (or tap the menu icon) opens the badge
// on garminbadges.com (GarminBadgesDetailDelegate); BACK pops back.
class GarminBadgesUpcomingDetailView extends WatchUi.View {

    private var _badge as Lang.Dictionary;

    function initialize(badge as Lang.Dictionary) {
        View.initialize();
        _badge = badge;
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

        var name    = _badge.get("name");
        var nameStr = (name != null) ? name as Lang.String : "";

        var daysUntil    = _badge.get("days_until");
        var daysUntilVal = (daysUntil != null) ? daysUntil as Lang.Number : 0;

        var duration    = _badge.get("duration_days");
        var durationVal = (duration != null) ? duration as Lang.Number : 0;

        // Title
        dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.08 + 0.5).toNumber(), BadgeFormat.glanceFont(), "UPCOMING", justify);

        // Name (wrapped, up to a few lines)
        var lineHeight = dc.getFontHeight(BadgeFormat.glanceFont());
        var nameTop    = (h * 0.24).toNumber();
        var nameLines  = BadgeFormat.wrapText(dc, nameStr, BadgeFormat.glanceFont(), BadgeFormat.textMaxWidth(w, h, nameTop));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < nameLines.size(); i += 1) {
            dc.drawText(cx, nameTop + i * lineHeight, BadgeFormat.glanceFont(), nameLines[i] as Lang.String, justify);
        }

        var contentTop = nameTop + nameLines.size() * lineHeight + (h * 0.06).toNumber();

        var fontHeight = dc.getFontHeight(BadgeFormat.glanceFont());
        var textGap    = (h * 0.02).toNumber();

        // Starts in
        dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, contentTop, BadgeFormat.glanceFont(), "Starts " + BadgeFormat.formatDaysUntil(daysUntilVal), justify);

        // Duration
        if (durationVal > 0) {
            var durationY = contentTop + fontHeight / 2 + textGap + fontHeight / 2;
            dc.drawText(cx, durationY, BadgeFormat.glanceFont(),
                "Duration: " + durationVal.toString() + "d", justify);
        }

        BadgeFormat.drawMenuIcon(dc, w, h);
    }
}
