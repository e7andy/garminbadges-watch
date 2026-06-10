import Toybox.Lang;
import Toybox.WatchUi;

class GarminBadgesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as GarminBadgesView;
    private var _lastDragY as Lang.Number?;

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

    // Touch drag — scroll the list 1:1 with the finger
    function onDrag(dragEvent as WatchUi.DragEvent) as Lang.Boolean {
        var y    = dragEvent.getCoordinates()[1];
        var type = dragEvent.getType();

        if (type == WatchUi.DRAG_TYPE_START) {
            _view.stopMomentum();
            _lastDragY = y;
            return true;
        }

        if (_lastDragY != null) {
            var deltaY = y - (_lastDragY as Lang.Number);
            _view.scrollBy(-deltaY);
        }
        _lastDragY = y;

        if (type == WatchUi.DRAG_TYPE_STOP) {
            _lastDragY = null;
        }

        return true;
    }

    // Touch flick release — keep scrolling with momentum
    function onFlick(flickEvent as WatchUi.FlickEvent) as Lang.Boolean {
        var direction = flickEvent.getDirection();
        var velocity  = flickEvent.getVelocity();

        // direction in degrees: up = 0, down = 180. Flicking up continues
        // scrolling the list down (increases _scrollOffset).
        if (direction < 90 || direction > 270) {
            _view.startMomentum(velocity);
        } else if (direction > 90 && direction < 270) {
            _view.startMomentum(-velocity);
        }

        return true;
    }
}
