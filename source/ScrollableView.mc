import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Base class providing momentum-based vertical scroll state shared by
// GarminBadgesView and GarminBadgesAllChallengesView.
class ScrollableView extends WatchUi.View {

    protected var _scrollOffset as Lang.Number = 0;
    protected var _maxScroll    as Lang.Number = 0;
    protected var _viewportTop  as Lang.Number = 0;
    protected var _rowHeightPx  as Lang.Number = 0;

    protected const ROW_HEIGHT_FRAC = 0.255;

    private var _momentumVelocity as Lang.Float = 0.0;
    private var _momentumTimer    as Timer.Timer?;

    private const MOMENTUM_FRICTION     = 0.95;
    private const MOMENTUM_MIN_VELOCITY = 10.0;
    private const MOMENTUM_TICK_MS      = 50;

    // Drives the page-flip ticker for row names too wide to fit (see
    // BadgeFormat.pagedText()).
    protected var _tickCount as Lang.Number = 0;
    private var _tickerTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _tickCount   = 0;
        _tickerTimer = new Timer.Timer();
        _tickerTimer.start(method(:onTickerTimer), BadgeFormat.TICKER_TICK_MS, true);
    }

    function onHide() as Void {
        stopMomentum();
        if (_tickerTimer != null) {
            _tickerTimer.stop();
            _tickerTimer = null;
        }
    }

    function onTickerTimer() as Void {
        _tickCount += 1;
        WatchUi.requestUpdate();
    }

    // Current tick count, for BadgeFormat.pagedText().
    function tickCount() as Lang.Number {
        return _tickCount;
    }

    // Top of the scrollable list, in screen y-coordinates.
    function viewportTop() as Lang.Number {
        return _viewportTop;
    }

    // Height of one row, in pixels, as last computed by onUpdate().
    function rowHeightPx() as Lang.Number {
        return _rowHeightPx;
    }

    // Index of the row at screen y-coordinate, or -1 if y is above the
    // viewport.
    function rowIndexAt(y as Lang.Number) as Lang.Number {
        if (y < _viewportTop) {
            return -1;
        }
        return ((y - _viewportTop + _scrollOffset) / _rowHeightPx).toNumber();
    }

    // True if the list is scrolled all the way to the top.
    function isScrolledToTop() as Lang.Boolean {
        return _scrollOffset == 0;
    }

    // Pushes the detail page for the given challenge.
    function showChallengeDetail(badge as Lang.Dictionary) as Void {
        var view     = new GarminBadgesChallengeDetailView(badge);
        var delegate = new GarminBadgesDetailDelegate(BadgeFormat.badgeUrl(badge));
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    // Pushes the detail page for the given upcoming badge.
    function showUpcomingDetail(badge as Lang.Dictionary) as Void {
        var view     = new GarminBadgesUpcomingDetailView(badge);
        var delegate = new GarminBadgesDetailDelegate(BadgeFormat.badgeUrl(badge));
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    function scrollBy(deltaPx as Lang.Number) as Void {
        stopMomentum();

        _scrollOffset += deltaPx;
        clampScroll();
        WatchUi.requestUpdate();
    }

    // Begin a momentum scroll after a flick release. velocityPxPerSec is
    // signed: positive scrolls down (increases _scrollOffset).
    function startMomentum(velocityPxPerSec as Lang.Float) as Void {
        stopMomentum();

        if (velocityPxPerSec.abs() < MOMENTUM_MIN_VELOCITY) {
            return;
        }

        _momentumVelocity = velocityPxPerSec;
        _momentumTimer    = new Timer.Timer();
        _momentumTimer.start(method(:onMomentumTick), MOMENTUM_TICK_MS, true);
    }

    function stopMomentum() as Void {
        if (_momentumTimer != null) {
            _momentumTimer.stop();
            _momentumTimer = null;
        }
        _momentumVelocity = 0.0;
    }

    function onMomentumTick() as Void {
        var deltaPx = (_momentumVelocity * (MOMENTUM_TICK_MS / 1000.0)).toNumber();
        _scrollOffset += deltaPx;

        var hitEdge = clampScroll();

        _momentumVelocity *= MOMENTUM_FRICTION;

        if (hitEdge || _momentumVelocity.abs() < MOMENTUM_MIN_VELOCITY) {
            stopMomentum();
        }

        WatchUi.requestUpdate();
    }

    // Clamps _scrollOffset to [0, _maxScroll]. Returns true if it was out of
    // range (i.e. a momentum scroll just hit the top/bottom edge).
    private function clampScroll() as Lang.Boolean {
        if (_scrollOffset < 0) {
            _scrollOffset = 0;
            return true;
        }
        if (_scrollOffset > _maxScroll) {
            _scrollOffset = _maxScroll;
            return true;
        }
        return false;
    }
}
