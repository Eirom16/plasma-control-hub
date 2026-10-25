// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../applets/systemtray/qml/ControlLayout.js" as Layout
TestCase {
    name: "ControlLayout"
    function test_moveRetainsUnselectedModules() {
        compare(Layout.move(["wifi", "bluetooth", "audio"], "audio", "wifi"), ["audio", "wifi", "bluetooth"]);
        compare(Layout.move(["wifi", "bluetooth"], "wifi", ""), ["bluetooth", "wifi"]);
    }
    function test_duplicatesAndMissingModules() {
        compare(Layout.move(["wifi", "wifi", "audio"], "audio", "wifi"), ["audio", "wifi"]);
        const entries = [{id:"audio",title:"Audio"},{id:"wifi",title:"Wi-Fi"},{id:"extra",title:"Extra"}];
        compare(Layout.sorted(entries, ["wifi", "removed", "audio"]).map(x => x.id), ["wifi", "audio", "extra"]);
    }
}
