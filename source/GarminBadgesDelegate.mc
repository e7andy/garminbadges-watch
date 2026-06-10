import Toybox.Lang;
import Toybox.WatchUi;

// Drag/flick/button scrolling is provided by ScrollDelegate.
class GarminBadgesDelegate extends ScrollDelegate {

    private var _view as GarminBadgesView;

    function initialize(view as GarminBadgesView) {
        ScrollDelegate.initialize(view);
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
}
