import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Detail page for an upcoming badge — pushed when an "UPCOMING" row is
// selected on the main page. BACK pops back (default BehaviorDelegate
// behavior).
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
        dc.drawText(cx, (h * 0.06 + 0.5).toNumber(), Graphics.FONT_XTINY, "UPCOMING", justify);

        // Name (wrapped, up to a few lines)
        var lineHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var nameTop    = (h * 0.2).toNumber();
        var nameLines  = BadgeFormat.wrapText(dc, nameStr, Graphics.FONT_SMALL, BadgeFormat.textMaxWidth(w, h, nameTop));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < nameLines.size(); i += 1) {
            dc.drawText(cx, nameTop + i * lineHeight, Graphics.FONT_SMALL, nameLines[i] as Lang.String, justify);
        }

        var contentTop = nameTop + nameLines.size() * lineHeight + (h * 0.06).toNumber();

        var smallFontHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var xtinyFontHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var textGap         = (h * 0.02).toNumber();

        // Starts in
        dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, contentTop, Graphics.FONT_SMALL, "Starts " + BadgeFormat.formatDaysUntil(daysUntilVal), justify);

        // Duration
        if (durationVal > 0) {
            var durationY = contentTop + smallFontHeight / 2 + textGap + xtinyFontHeight / 2;
            dc.drawText(cx, durationY, Graphics.FONT_XTINY,
                durationVal.toString() + "-day challenge", justify);
        }
    }
}
