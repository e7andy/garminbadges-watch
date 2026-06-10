import Toybox.Lang;
import Toybox.WatchUi;

class GarminBadgesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as GarminBadgesView;

    private const SCROLL_STEP = 40;

    function initialize(view as GarminBadgesView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT button / tap — open the all-challenges page when scrolled to the
    // "MORE" row, otherwise refresh data
    function onSelect() as Lang.Boolean {
        if (_view.atMoreRow()) {
            _view.showAllChallenges();
        } else {
            _view.fetchData();
        }
        return true;
    }

    // MENU button — open the all-challenges page if there are more than fit
    function onMenu() as Lang.Boolean {
        if (_view.hasMoreChallenges()) {
            _view.showAllChallenges();
            return true;
        }
        return false;
    }

    // DOWN button — scroll challenges list down
    function onNextPage() as Lang.Boolean {
        _view.scrollBy(SCROLL_STEP);
        return true;
    }

    // UP button — scroll challenges list up
    function onPreviousPage() as Lang.Boolean {
        _view.scrollBy(-SCROLL_STEP);
        return true;
    }

    // Touchscreen swipe — scroll challenges list
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
