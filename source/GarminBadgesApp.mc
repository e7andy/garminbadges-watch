import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GarminBadgesApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new GarminBadgesView();
        return [view, new GarminBadgesDelegate(view)];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new GarminBadgesGlanceView()];
    }
}

function getApp() as GarminBadgesApp {
    return Application.getApp() as GarminBadgesApp;
}
