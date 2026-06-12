import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Drag/flick/button scrolling is provided by ScrollDelegate (harmless
// no-ops on this page, since GarminBadgesView never sets _maxScroll > 0).
class GarminBadgesDelegate extends ScrollDelegate {

    private var _view as GarminBadgesView;
    private var _menuHoldTimer as Timer.Timer?;

    private const MENU_HOLD_MS = 700;

    function initialize(view as GarminBadgesView) {
        ScrollDelegate.initialize(view);
        _view = view;
    }

    // DOWN button — move the section selection forward.
    function onNextPage() as Lang.Boolean {
        _view.moveSelection(1);
        WatchUi.requestUpdate();
        return true;
    }

    // UP button — move the section selection back.
    function onPreviousPage() as Lang.Boolean {
        _view.moveSelection(-1);
        WatchUi.requestUpdate();
        return true;
    }

    // Opens the "All <Section>" page for the given section id. Returns false
    // if sectionId is -1 (no section there).
    private function openSection(sectionId as Lang.Number) as Lang.Boolean {
        if (sectionId == BadgeFormat.SECTION_UPCOMING) {
            _view.showAllUpcoming();
            return true;
        }
        if (sectionId == BadgeFormat.SECTION_ENDING_SOON) {
            _view.showAllEndingSoon();
            return true;
        }
        if (sectionId == BadgeFormat.SECTION_CHALLENGES) {
            _view.showAllChallenges();
            return true;
        }
        return false;
    }

    // Cancels the pending menu-hold timer (called once START/STOP is
    // released, whether or not it navigated anywhere).
    private function cancelMenuHoldTimer() as Void {
        if (_menuHoldTimer != null) {
            _menuHoldTimer.stop();
            _menuHoldTimer = null;
        }
    }

    // Touch tap on the menu icon (top-right corner) — show the options menu;
    // tap on any row within a section — open that section's "All" page.
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords   = clickEvent.getCoordinates();
        var settings = System.getDeviceSettings();
        if (BadgeFormat.isMenuIconHit(coords[0], coords[1], settings.screenWidth, settings.screenHeight)) {
            return onMenu();
        }

        return openSection(_view.sectionAt(coords[1]));
    }

    // Holding START/STOP also opens the options menu
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _menuHoldTimer = new Timer.Timer();
            _menuHoldTimer.start(method(:onMenuHoldTimer), MENU_HOLD_MS, false);
        }
        return false;
    }

    // START/STOP released before the hold timer fired — open the "All"
    // page for the selected section, same as a tap. If the timer already
    // fired (a long hold), onMenu() has already run, so do nothing.
    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }

        if (_menuHoldTimer == null) {
            return false;
        }
        cancelMenuHoldTimer();

        return openSection(_view.selectedSection());
    }

    function onMenuHoldTimer() as Void {
        _menuHoldTimer = null;
        onMenu();
    }

    // MENU button (or hold START/STOP, or tap the menu icon) — show options menu
    function onMenu() as Lang.Boolean {
        var menu = new WatchUi.Menu2({:title => "Menu"});
        menu.addItem(new WatchUi.MenuItem("Refresh", null, :refresh, {}));
        WatchUi.pushView(menu, new GarminBadgesMenuDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }
}
