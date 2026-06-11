import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Detail page for a single challenge — pushed when a row is selected on
// the main or all-challenges pages. BACK pops back (default
// BehaviorDelegate behavior).
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
        dc.drawText(cx, (h * 0.06 + 0.5).toNumber(), Graphics.FONT_XTINY, "CHALLENGE", justify);

        // Name (wrapped, up to a few lines)
        var lineHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var nameTop    = (h * 0.16).toNumber();
        var nameLines  = BadgeFormat.wrapText(dc, nameStr, Graphics.FONT_SMALL, BadgeFormat.textMaxWidth(w, h, nameTop));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < nameLines.size(); i += 1) {
            dc.drawText(cx, nameTop + i * lineHeight, Graphics.FONT_SMALL, nameLines[i] as Lang.String, justify);
        }

        var contentTop = nameTop + nameLines.size() * lineHeight + (h * 0.03).toNumber();

        var smallFontHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var xtinyFontHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var textGap         = (h * 0.02).toNumber();

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
            dc.drawText(cx, barTop + barHeight / 2, Graphics.FONT_XTINY,
                (ratio * 100).toNumber().toString() + "%", justify);

            // Fraction
            var fractionY = barTop + barHeight + textGap + smallFontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, fractionY, Graphics.FONT_SMALL,
                BadgeFormat.formatFraction(progressVal, targetVal, unitStr), justify);

            contentTop = fractionY + smallFontHeight + textGap;
        } else {
            var noTargetY = contentTop + textGap + smallFontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, noTargetY, Graphics.FONT_SMALL, "No target", justify);
            contentTop = noTargetY + smallFontHeight + textGap;
        }

        // Days behind/ahead schedule, or days until start
        var statusText = "";
        if (!startedVal) {
            statusText = "Starts " + BadgeFormat.formatDaysUntil(daysUntilStartVal);
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        } else if (daysBehindVal >= 0.5) {
            statusText = BadgeFormat.formatNum(daysBehindVal) + "d behind schedule";
            dc.setColor(BadgeFormat.RED, Graphics.COLOR_TRANSPARENT);
        } else if (daysBehindVal <= -0.5) {
            statusText = BadgeFormat.formatNum(-daysBehindVal) + "d ahead of schedule";
            dc.setColor(BadgeFormat.GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            statusText = "On track";
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, contentTop, Graphics.FONT_SMALL, statusText, justify);

        // Duration
        if (durationVal > 0) {
            var durationY = contentTop + smallFontHeight / 2 + textGap + xtinyFontHeight / 2;
            dc.setColor(BadgeFormat.GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, durationY, Graphics.FONT_XTINY,
                durationVal.toString() + "-day challenge", justify);
        }
    }
}
