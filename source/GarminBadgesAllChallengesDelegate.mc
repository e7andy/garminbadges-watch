import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the "all challenges" page. BACK pops back to the
// main page (default BehaviorDelegate behavior). Drag/flick/button
// scrolling is provided by ScrollDelegate.
class GarminBadgesAllChallengesDelegate extends ScrollDelegate {

    function initialize(view as GarminBadgesAllChallengesView) {
        ScrollDelegate.initialize(view);
    }
}
