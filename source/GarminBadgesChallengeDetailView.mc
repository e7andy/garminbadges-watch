import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Detail page for a single challenge — pushed when a row is selected on
// the main or all-challenges pages. MENU (or tap the menu icon)
// opens the badge on garminbadges.com (GarminBadgesDetailDelegate); BACK
// pops back.
class GarminBadgesChallengeDetailView extends WatchUi.View {

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

        var progressVal   = BadgeFormat.toFloatVal(_badge.get("progress_value"), 0.0);
        var targetVal     = BadgeFormat.toFloatVal(_badge.get("target_value"), 0.0);
        var unit          = _badge.get("unit_key");
        var unitStr       = (unit != null) ? unit as Lang.String : "";
        var daysBehindVal = BadgeFormat.toFloatVal(_badge.get("days_behind"), 0.0);

        var duration    = _badge.get("duration_days");
        var durationVal = (duration != null) ? duration as Lang.Number : 0;

        var started    = _badge.get("started");
        var startedVal = (started == null) || (started as Lang.Boolean);

        var daysUntilStart    = _badge.get("days_until_start");
        var daysUntilStartVal = (daysUntilStart != null) ? daysUntilStart as Lang.Number : 0;

        var hasTarget = targetVal > 0;

        // Title
        dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.08 + 0.5).toNumber(), BadgeFormat.glanceFont(), "CHALLENGE", justify);

        // Name (wrapped, up to a few lines)
        var lineHeight = dc.getFontHeight(BadgeFormat.glanceFont());
        var nameTop    = (h * 0.2).toNumber();
        var nameLines  = BadgeFormat.wrapText(dc, nameStr, BadgeFormat.glanceFont(), BadgeFormat.textMaxWidth(w, h, nameTop));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < nameLines.size(); i += 1) {
            dc.drawText(cx, nameTop + i * lineHeight, BadgeFormat.glanceFont(), nameLines[i] as Lang.String, justify);
        }

        var contentTop = nameTop + nameLines.size() * lineHeight + (h * 0.03).toNumber();

        var fontHeight = dc.getFontHeight(BadgeFormat.glanceFont());
        var textGap    = (h * 0.035).toNumber();

        var daysColor = BadgeFormat.GRAY;
        if (daysBehindVal >= 0.5) {
            daysColor = BadgeFormat.RED;
        } else if (daysBehindVal <= -0.5) {
            daysColor = BadgeFormat.GREEN;
        }

        if (hasTarget) {
            var ratio = progressVal / targetVal;
            if (ratio > 1.0) { ratio = 1.0; }
            if (ratio < 0.0) { ratio = 0.0; }

            var barLeft   = (w * 0.1).toNumber();
            var barWidth  = (w * 0.8).toNumber();
            var barTop    = contentTop;
            var barHeight = (h * 0.07).toNumber();

            dc.setColor(BadgeFormat.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(barLeft, barTop, barWidth, barHeight);

            var fillWidth = (barWidth * ratio).toNumber();
            if (fillWidth > 0) {
                dc.setColor(daysColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barLeft, barTop, fillWidth, barHeight);
            }

            // Percentage
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, barTop + barHeight / 2, BadgeFormat.glanceFont(),
                (ratio * 100).toNumber().toString() + "%", justify);

            // Fraction
            var fractionY = barTop + barHeight + textGap + fontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, fractionY, BadgeFormat.glanceFont(),
                BadgeFormat.formatFraction(progressVal, targetVal, unitStr), justify);

            contentTop = fractionY + fontHeight + textGap;
        } else {
            var noTargetY = contentTop + textGap + fontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, noTargetY, BadgeFormat.glanceFont(), "No target", justify);
            contentTop = noTargetY + fontHeight + textGap;
        }

        // Days behind/ahead, or days until start
        var statusText = "";
        if (!startedVal) {
            statusText = "Starts " + BadgeFormat.formatDaysUntil(daysUntilStartVal);
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        } else if (daysBehindVal >= 0.5) {
            statusText = BadgeFormat.formatNum(daysBehindVal) + "d behind";
            dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        } else if (daysBehindVal <= -0.5) {
            statusText = BadgeFormat.formatNum(-daysBehindVal) + "d ahead";
            dc.setColor(BadgeFormat.GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            statusText = "On track";
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, contentTop, BadgeFormat.glanceFont(), statusText, justify);

        // Duration
        if (durationVal > 0) {
            var durationY = contentTop + fontHeight / 2 + textGap + fontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, durationY, BadgeFormat.glanceFont(),
                "Duration: " + durationVal.toString() + "d", justify);
        }

        BadgeFormat.drawMenuIcon(dc, w, h);
    }
}
