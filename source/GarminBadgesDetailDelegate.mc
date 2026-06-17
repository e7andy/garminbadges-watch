import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Shared delegate for the challenge/upcoming detail pages. MENU (button,
// hold START/STOP — see GarminBadgesDelegate's pattern, or tap the menu
// icon) opens a menu with "View Online", which opens the badge's
// garminbadges.com page on the phone via Garmin Connect Mobile
// (GarminBadgesDetailMenuDelegate). BACK pops (default BehaviorDelegate
// behavior).
class GarminBadgesDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _url as Lang.String?;

    function initialize(url as Lang.String?) {
        BehaviorDelegate.initialize();
        _url = url;
    }

    // Tapping the menu icon (top-right corner) also opens the menu.
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords   = clickEvent.getCoordinates();
        var settings = System.getDeviceSettings();
        if (BadgeFormat.isMenuIconHit(coords[0], coords[1], settings.screenWidth, settings.screenHeight)) {
            return onMenu();
        }
        return false;
    }

    // Always shows the menu, even if _url is null (e.g. stale BadgeCache
    // data from before the API returned an "id") — returning false here
    // would let the event fall through to the previously pushed view's
    // delegate (e.g. the main page's "Refresh" menu), which is more
    // confusing than a "View Online" item that no-ops until refreshed.
    function onMenu() as Lang.Boolean {
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("View Online", null, :viewOnline, {}));
        WatchUi.pushView(menu, new GarminBadgesDetailMenuDelegate(_url), WatchUi.SLIDE_UP);
        return true;
    }
}
