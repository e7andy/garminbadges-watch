import Toybox.Lang;
import Toybox.WatchUi;

// Handles selections in the main page's options menu (MENU button).
class GarminBadgesMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as GarminBadgesView;

    function initialize(view as GarminBadgesView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == :refresh) {
            _view.fetchData(false);
        }
    }
}
