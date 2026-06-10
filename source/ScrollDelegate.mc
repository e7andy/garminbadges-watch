import Toybox.Lang;
import Toybox.WatchUi;

// Base delegate providing shared touch-drag, flick-momentum, and button
// scrolling for GarminBadgesDelegate and GarminBadgesAllChallengesDelegate.
class ScrollDelegate extends WatchUi.BehaviorDelegate {

    private var _scrollView as ScrollableView;
    private var _lastDragY  as Lang.Number?;

    private const SCROLL_STEP = 40;

    function initialize(view as ScrollableView) {
        BehaviorDelegate.initialize();
        _scrollView = view;
    }

    // DOWN button — scroll list down
    function onNextPage() as Lang.Boolean {
        _scrollView.scrollBy(SCROLL_STEP);
        return true;
    }

    // UP button — scroll list up
    function onPreviousPage() as Lang.Boolean {
        _scrollView.scrollBy(-SCROLL_STEP);
        return true;
    }

    // Touch drag — scroll the list 1:1 with the finger
    function onDrag(dragEvent as WatchUi.DragEvent) as Lang.Boolean {
        var y    = dragEvent.getCoordinates()[1];
        var type = dragEvent.getType();

        if (type == WatchUi.DRAG_TYPE_START) {
            _scrollView.stopMomentum();
            _lastDragY = y;
            return true;
        }

        if (_lastDragY != null) {
            var deltaY = y - (_lastDragY as Lang.Number);
            _scrollView.scrollBy(-deltaY);
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
            _scrollView.startMomentum(velocity);
        } else if (direction > 90 && direction < 270) {
            _scrollView.startMomentum(-velocity);
        }

        return true;
    }
}
