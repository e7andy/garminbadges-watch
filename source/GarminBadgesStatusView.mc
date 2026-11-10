import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// "Sync status" screen (options menu): the outcome of the latest fetch (from
// the app or the glance), when data last synced successfully, and device
// state, so a "the data isn't updating" report can be diagnosed on the watch.
class GarminBadgesStatusView extends WatchUi.View {

    private var _challengeCount as Lang.Number;
    private var _upcomingCount  as Lang.Number;

    function initialize(challengeCount as Lang.Number, upcomingCount as Lang.Number) {
        View.initialize();
        _challengeCount = challengeCount;
        _upcomingCount  = upcomingCount;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var lines  = [] as Lang.Array<Lang.Array>;  // [text, color]
        var status = BadgeCache.status();
        var now    = Time.now().value();

        if (status == null) {
            lines.add(["No sync recorded yet", BadgeFormat.GRAY]);
        } else {
            var code   = status.get("code") as Lang.Number;
            var detail = status.get("detail");
            var ok     = (status.get("ok") == true);
            var at     = status.get("at") as Lang.Number;

            lines.add([(ok ? "Last sync OK " : "Last sync FAILED ") + BadgeFormat.formatAge(now - at),
                ok ? BadgeFormat.GREEN : BadgeFormat.RED]);
            lines.add(["Code " + code.toString() + ": " + BadgeFormat.describeCode(code), Graphics.COLOR_WHITE]);
            if (detail != null) {
                lines.add([detail as Lang.String, BadgeFormat.RED]);
            }
            lines.add(["By " + (status.get("src") as Lang.String), BadgeFormat.GRAY]);

            var okAt = status.get("okAt");
            lines.add([(okAt instanceof Lang.Number)
                ? "Last OK " + BadgeFormat.formatAge(now - (okAt as Lang.Number))
                : "Never synced OK", BadgeFormat.GRAY]);
        }

        lines.add([_challengeCount.toString() + " challenges, " + _upcomingCount.toString() + " upcoming", BadgeFormat.GRAY]);

        var stats = System.getSystemStats();
        lines.add(["Free mem " + (stats.freeMemory / 1024).toString() + "k", BadgeFormat.GRAY]);
        lines.add([System.getDeviceSettings().phoneConnected ? "Phone connected" : "Phone NOT connected",
            System.getDeviceSettings().phoneConnected ? BadgeFormat.GRAY : BadgeFormat.RED]);

        var font       = Graphics.FONT_XTINY;
        var lineHeight = dc.getFontHeight(font);
        var y          = (h * 0.14).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, BadgeFormat.glanceFont(), "Sync status", Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(BadgeFormat.glanceFont()) + (h * 0.01).toNumber();

        for (var i = 0; i < lines.size(); i += 1) {
            var line    = lines[i] as Lang.Array;
            var wrapped = BadgeFormat.wrapText(dc, line[0] as Lang.String, font, BadgeFormat.textMaxWidth(w, h, y));
            dc.setColor(line[1] as Lang.Number, Graphics.COLOR_TRANSPARENT);
            for (var j = 0; j < wrapped.size(); j += 1) {
                dc.drawText(w / 2, y, font, wrapped[j] as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
                y += lineHeight;
            }
        }
    }
}
