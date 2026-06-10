import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Base class providing momentum-based vertical scroll state shared by
// GarminBadgesView and GarminBadgesAllChallengesView.
class ScrollableView extends WatchUi.View {

    protected var _scrollOffset as Lang.Number = 0;
    protected var _maxScroll    as Lang.Number = 0;

    protected const ROW_HEIGHT_FRAC = 0.255;

    private var _momentumVelocity as Lang.Float = 0.0;
    private var _momentumTimer    as Timer.Timer?;

    private const MOMENTUM_FRICTION     = 0.95;
    private const MOMENTUM_MIN_VELOCITY = 10.0;
    private const MOMENTUM_TICK_MS      = 50;

    function initialize() {
        View.initialize();
    }

    function onHide() as Void {
        stopMomentum();
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
