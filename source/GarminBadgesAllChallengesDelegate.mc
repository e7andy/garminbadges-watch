import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the "all challenges" page. BACK pops back to the
// main page (default BehaviorDelegate behavior). Drag/flick/button
// scrolling is provided by ScrollDelegate. SELECT/tap on a challenge row
// opens its detail page.
class GarminBadgesAllChallengesDelegate extends ScrollDelegate {

    private var _view as GarminBadgesAllChallengesView;

    function initialize(view as GarminBadgesAllChallengesView) {
        ScrollDelegate.initialize(view);
        _view = view;
    }

    function onSelect() as Lang.Boolean {
        var challenge = _view.challengeAt(_view.viewportTop());
        if (challenge != null) {
            _view.showChallengeDetail(challenge);
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords    = clickEvent.getCoordinates();
        var challenge = _view.challengeAt(coords[1]);
        if (challenge != null) {
            _view.showChallengeDetail(challenge);
            return true;
        }
        return false;
    }
}
