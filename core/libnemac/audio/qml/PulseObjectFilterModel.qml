import Nemac.Audio 1.0

SortFilterModel {
    property var filters: []
    property bool filterOutInactiveDevices: false

    function role(name) {
        return sourceModel.role(name);
    }

}
