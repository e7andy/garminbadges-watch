import Toybox.Lang;
import Toybox.WatchUi;

class GarminBadgesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as GarminBadgesView;

    function initialize(view as GarminBadgesView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT button / screen tap — refresh data
    function onSelect() as Lang.Boolean {
        _view.fetchData();
        return true;
    }
}
