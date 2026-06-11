import Toybox.Lang;
import Toybox.WatchUi;

// Base delegate providing shared touch-drag, flick-momentum, and button
// scrolling for GarminBadgesDelegate and GarminBadgesAllChallengesDelegate.
class ScrollDelegate extends WatchUi.BehaviorDelegate {

    private var _scrollView        as ScrollableView;
    private var _lastDragY         as Lang.Number?;

    function initialize(view as ScrollableView) {
        BehaviorDelegate.initialize();
        _scrollView = view;
    }

    // A tap is translated into a coordinate-less onSelect() call before
    // onTap(clickEvent), which has the tap coordinates. Returning false here
    // lets the system fall back to onTap(). Physical Start/Enter button
    // presses are handled directly via onKeyPressed()/onKeyReleased() in
    // subclasses instead, since those fire reliably for hardware keys.
    function onSelect() as Lang.Boolean {
        return false;
    }

    // DOWN button — scroll list down by one item
    function onNextPage() as Lang.Boolean {
        _scrollView.scrollBy(_scrollView.rowHeightPx());
        return true;
    }

    // UP button — scroll list up by one item
    function onPreviousPage() as Lang.Boolean {
        _scrollView.scrollBy(-_scrollView.rowHeightPx());
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
