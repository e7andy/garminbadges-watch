import Toybox.Application.Storage;
import Toybox.Lang;

// Persists the latest /api/watch response so the main view and glance can
// show data immediately on launch while a fresh copy is fetched in the
// background.
module BadgeCache {

    const KEY = "watchData";

    function load() as Lang.Dictionary? {
        var data = Storage.getValue(KEY);
        if (data instanceof Lang.Dictionary) {
            return data as Lang.Dictionary;
        }
        return null;
    }

    function save(data as Lang.Dictionary) as Void {
        Storage.setValue(KEY, data);
    }
}
