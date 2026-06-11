import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Drag/flick/button scrolling is provided by ScrollDelegate.
class GarminBadgesDelegate extends ScrollDelegate {

    private var _view as GarminBadgesView;
    private var _menuHoldTimer as Timer.Timer?;

    private const MENU_HOLD_MS = 700;

    function initialize(view as GarminBadgesView) {
        ScrollDelegate.initialize(view);
        _view = view;
    }

    // SELECT button / tap — open the all-challenges page when scrolled to the
    // "MORE" row
    function onSelect() as Lang.Boolean {
        if (_view.atMoreRow()) {
            _view.showAllChallenges();
            return true;
        }
        return false;
    }

    // Touch tap on the menu icon (top-right corner) — show the options menu
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords   = clickEvent.getCoordinates();
        var settings = System.getDeviceSettings();
        if (BadgeFormat.isMenuIconHit(coords[0], coords[1], settings.screenWidth, settings.screenHeight)) {
            return onMenu();
        }
        return false;
    }

    // Holding START/STOP also opens the options menu
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _menuHoldTimer = new Timer.Timer();
            _menuHoldTimer.start(method(:onMenuHoldTimer), MENU_HOLD_MS, false);
        }
        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (_menuHoldTimer != null) {
            _menuHoldTimer.stop();
            _menuHoldTimer = null;
        }
        return false;
    }

    function onMenuHoldTimer() as Void {
        _menuHoldTimer = null;
        onMenu();
    }

    // MENU button (or hold START/STOP, or tap the menu icon) — show options
    // menu (refresh, plus all-challenges if there are more than fit on the
    // main page)
    function onMenu() as Lang.Boolean {
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Refresh", null, :refresh, {}));
        if (_view.hasMoreChallenges()) {
            menu.addItem(new WatchUi.MenuItem("All Challenges", null, :allChallenges, {}));
        }
        WatchUi.pushView(menu, new GarminBadgesMenuDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }
}
