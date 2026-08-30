import Toybox.Lang;
import Toybox.WatchUi;

//! Resource lookups for the two tables that are indexed by number. A switch
//! keeps this allocation-free; building an array of resource ids on every call
//! would churn the heap during animation frames.
module Names {

    function crew(index as Number) as String {
        var id;
        switch (index) {
            case 0: id = Rez.Strings.Miner0; break;
            case 1: id = Rez.Strings.Miner1; break;
            case 2: id = Rez.Strings.Miner2; break;
            case 3: id = Rez.Strings.Miner3; break;
            case 4: id = Rez.Strings.Miner4; break;
            case 5: id = Rez.Strings.Miner5; break;
            case 6: id = Rez.Strings.Miner6; break;
            case 7: id = Rez.Strings.Miner7; break;
            default: id = Rez.Strings.Miner8; break;
        }
        return WatchUi.loadResource(id) as String;
    }

    function layer(index as Number) as String {
        var id;
        switch (index) {
            case 0: id = Rez.Strings.Layer0; break;
            case 1: id = Rez.Strings.Layer1; break;
            case 2: id = Rez.Strings.Layer2; break;
            case 3: id = Rez.Strings.Layer3; break;
            case 4: id = Rez.Strings.Layer4; break;
            case 5: id = Rez.Strings.Layer5; break;
            case 6: id = Rez.Strings.Layer6; break;
            default: id = Rez.Strings.Layer7; break;
        }
        return WatchUi.loadResource(id) as String;
    }

    //! Shorthand for the many one-off labels the custom views draw.
    function get(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}
