import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the "all upcoming" page. BACK pops back to the main
// page (default BehaviorDelegate behavior). Drag/flick/button scrolling is
// provided by ScrollDelegate. SELECT/tap on a row opens its detail page.
class GarminBadgesAllUpcomingDelegate extends ScrollDelegate {

    private var _view as GarminBadgesAllUpcomingView;

    function initialize(view as GarminBadgesAllUpcomingView) {
        ScrollDelegate.initialize(view);
        _view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords  = clickEvent.getCoordinates();
        var upcoming = _view.upcomingAt(coords[1]);
        if (upcoming != null) {
            _view.showUpcomingDetail(upcoming);
            return true;
        }
        return false;
    }

    // Start/Enter button — open the detail page for the row at the top of
    // the viewport (the implicitly "selected" row).
    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }

        var upcoming = _view.upcomingAt(_view.viewportTop());
        if (upcoming != null) {
            _view.showUpcomingDetail(upcoming);
            return true;
        }
        return false;
    }
}
