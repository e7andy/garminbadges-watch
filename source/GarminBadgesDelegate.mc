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
    // "MORE" row, otherwise open the detail page for the selected challenge
    function onSelect() as Lang.Boolean {
        if (!consumeSelectFromButton()) {
            return false;
        }

        var selUp = _view.selectedUpcomingIndex();
        if (selUp >= 0) {
            var upcoming = _view.upcomingBadgeAt(selUp);
            if (upcoming != null) {
                cancelMenuHoldTimer();
                _view.showUpcomingDetail(upcoming);
                return true;
            }
        }

        if (_view.atMoreRow()) {
            // Cancel any pending menu-hold timer so it doesn't fire onMenu()
            // on top of the page we're about to navigate to (this delegate
            // won't receive the matching onKeyReleased once that happens).
            cancelMenuHoldTimer();
            _view.showAllChallenges();
            return true;
        }

        var challenge = _view.challengeAt(_view.viewportTop());
        if (challenge != null) {
            cancelMenuHoldTimer();
            _view.showChallengeDetail(challenge);
            return true;
        }
        return false;
    }

    // DOWN button — move the "UPCOMING" selection forward, or once past the
    // last upcoming row, scroll the challenges list down by one row.
    function onNextPage() as Lang.Boolean {
        var upCount = _view.upcomingCount();
        var selUp   = _view.selectedUpcomingIndex();

        if (selUp >= 0) {
            if (selUp < upCount - 1) {
                _view.setSelectedUpcomingIndex(selUp + 1);
            } else {
                _view.setSelectedUpcomingIndex(-1);
            }
            WatchUi.requestUpdate();
            return true;
        }

        _view.scrollBy(_view.rowHeightPx());
        return true;
    }

    // UP button — scroll the challenges list up by one row, or once at the
    // top, move into the "UPCOMING" selection.
    function onPreviousPage() as Lang.Boolean {
        var upCount = _view.upcomingCount();
        var selUp   = _view.selectedUpcomingIndex();

        if (selUp == -1) {
            if (upCount > 0 && _view.isScrolledToTop()) {
                _view.setSelectedUpcomingIndex(upCount - 1);
                WatchUi.requestUpdate();
                return true;
            }
            _view.scrollBy(-_view.rowHeightPx());
            return true;
        }

        if (selUp > 0) {
            _view.setSelectedUpcomingIndex(selUp - 1);
            WatchUi.requestUpdate();
        }
        return true;
    }

    // Cancels any pending menu-hold timer so it doesn't fire onMenu() on top
    // of the page we're about to navigate to (this delegate won't receive the
    // matching onKeyReleased once that happens).
    private function cancelMenuHoldTimer() as Void {
        if (_menuHoldTimer != null) {
            _menuHoldTimer.stop();
            _menuHoldTimer = null;
        }
    }

    // Touch tap on the menu icon (top-right corner) — show the options menu;
    // tap on an "UPCOMING" or challenge row — open its detail page
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords   = clickEvent.getCoordinates();
        var settings = System.getDeviceSettings();
        if (BadgeFormat.isMenuIconHit(coords[0], coords[1], settings.screenWidth, settings.screenHeight)) {
            return onMenu();
        }

        var upcoming = _view.upcomingAt(coords[1]);
        if (upcoming != null) {
            _view.showUpcomingDetail(upcoming);
            return true;
        }

        var challenge = _view.challengeAt(coords[1]);
        if (challenge != null) {
            _view.showChallengeDetail(challenge);
            return true;
        }
        return false;
    }

    // Holding START/STOP also opens the options menu
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            markKeyEnterPressed();
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
