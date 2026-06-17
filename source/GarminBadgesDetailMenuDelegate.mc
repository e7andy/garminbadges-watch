import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Handles selections in a detail page's options menu (GarminBadgesDetailDelegate.onMenu()).
class GarminBadgesDetailMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _url as Lang.String?;

    function initialize(url as Lang.String?) {
        Menu2InputDelegate.initialize();
        _url = url;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == :viewOnline && _url != null) {
            Communications.openWebPage(_url, null, null);
        }
    }
}
