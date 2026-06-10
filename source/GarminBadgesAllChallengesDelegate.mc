import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the "all challenges" page. BACK pops back to the
// main page (default BehaviorDelegate behavior).
class GarminBadgesAllChallengesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as GarminBadgesAllChallengesView;

    private const SCROLL_STEP = 40;

    function initialize(view as GarminBadgesAllChallengesView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // DOWN button — scroll list down
    function onNextPage() as Lang.Boolean {
        _view.scrollBy(SCROLL_STEP);
        return true;
    }

    // UP button — scroll list up
    function onPreviousPage() as Lang.Boolean {
        _view.scrollBy(-SCROLL_STEP);
        return true;
    }

    // Touchscreen swipe — scroll list
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Lang.Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_UP) {
            _view.scrollBy(SCROLL_STEP);
            return true;
        } else if (direction == WatchUi.SWIPE_DOWN) {
            _view.scrollBy(-SCROLL_STEP);
            return true;
        }
        return false;
    }
}
