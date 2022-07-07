/*
 * Copyright 2021  Atul Gopinathan  <leoatul12@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */

import QtQuick 2.6
import QtQuick.Layouts 1.1
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0


Item {
    id: main
    anchors.fill: parent

    //height and width, when the widget is placed in desktop
    width: 100
    height: 40

    //height and width, when widget is placed in plasma panel
    Layout.preferredWidth: 80 * units.devicePixelRatio
    Layout.preferredHeight: 40 * units.devicePixelRatio

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    property var batteryObjects: getBatteryDirectoryPaths()
    property double power: getPowerUsageOfAllBatteries(batteryObjects)

    //this function tries to get the directory paths to all the batteries
    //present under /sys/class/power_supply
    function getBatteryDirectoryPaths() {
        var batteryObjects = []
        for(var i=0; i<4; i++) {
            var path = "/sys/class/power_supply/BAT" + i + "/present";
            var req = new XMLHttpRequest();
            req.open("GET", path, false);
            req.send(null)

            if(req.responseText == "1\n") {
                var directoryUrl =  "/sys/class/power_supply/BAT" + i;

                var battery = {
                    directoryUrl: directoryUrl,
                    powerNowFileExists: checkPowerNowFileExists(directoryUrl)
                }

                batteryObjects.push(battery)
            }
        }

        return batteryObjects
    }

    //this function checks if the "/sys/class/power_supply/BAT[i]/power_now" file exists
    function checkPowerNowFileExists(batteryDirectoryUrl) {

        var path = batteryDirectoryUrl + "/power_now"
        var req = new XMLHttpRequest();

        req.open("GET", path, false);
        req.send(null);

        if(req.responseText == "") {
            return false
        }
        else {
            return true
        }
    }

    function getPowerUsageOfAllBatteries(batteries) {
        var powerConsumed = 0.0;
        if(batteries.length == 0) {
            return "0.0"
        }

        for (var batteryIndex = 0; batteryIndex < batteries.length; batteryIndex++) {
            powerConsumed = powerConsumed + getPowerUsage(batteries[batteryIndex]);
        }

        return powerConsumed
    }

    //Returns power usage of the battery passed as argument in Watts, rounded off to 1 decimal.
    function getPowerUsage(battery) {

        //in case the "power_now" file exists:
        if (battery.powerNowFileExists == true) {
            var powerNowFileUrl = battery.directoryUrl + "/power_now"
            var req = new XMLHttpRequest();
            req.open("GET", powerNowFileUrl, false);
            req.send(null);

            var power = parseInt(req.responseText) / 1000000;
            return(Math.round(power*10)/10);
        }

        //if the power_now file doesn't exist, we collect voltage
        //and current and manually calculate power consumption
        var curUrl = battery.directoryUrl + "/current_now"
        var voltUrl = battery.directoryUrl + "/voltage_now"

        var curReq = new XMLHttpRequest();
        var voltReq = new XMLHttpRequest();

        curReq.open("GET", curUrl, false);
        voltReq.open("GET", voltUrl, false);

        curReq.send(null);
        voltReq.send(null);

        var power = (parseInt(curReq.responseText) * parseInt(voltReq.responseText))/1000000000000;
        return Math.round(power*10)/10; //toFixed() is apparently slow, so we use this way
    }

    // adds a 🗲 symbol if any of the batteries in the laptop are charging
    function chargingStatusText() {
        if (plasmoid.configuration.showChargingStatus == true) {
            for (var batteryIndex = 0; batteryIndex < main.batteryObjects.length; batteryIndex++) {
                var path = batteryObjects[batteryIndex].directoryUrl + "/status"
                var req = new XMLHttpRequest();
                req.open("GET", path, false);
                req.send(null);

                if (req.responseText == "Charging\n") {
                    return " 🗲";
                }
            }
        }

        return "";
    }

    PlasmaComponents.Label {
        id: display

        anchors {
            fill: parent
            margins: Math.round(parent.width * 0.01)
        }

        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        text: {
            if(Number.isInteger(main.power)) {
                return(main.power + ".0 W" + chargingStatusText());
            }
            else {
                return(main.power + " W" + chargingStatusText());
            }
        }

        font.pixelSize: 1000;
        minimumPointSize: theme.smallestFont.pointSize
        fontSizeMode: Text.Fit
        font.bold: plasmoid.configuration.makeFontBold
    }

    Timer {
        interval: plasmoid.configuration.updateInterval * 1000
        running: true
        repeat: true
        onTriggered: {
            main.power = getPowerUsageOfAllBatteries(main.batteryObjects)
            if(Number.isInteger(main.power)) {
                //When power has 0 decimal places, it removes the decimal
                //point inspite of power variable being double. This momentarily
                //makes the font size bigger due to extra available space which
                //does not look good. So we do this simple hack of manually adding
                //a .0 to number
                display.text = main.power + ".0 W" + chargingStatusText();
            }
            else {
                display.text = main.power + " W" + chargingStatusText();
            }
        }
    }
}
