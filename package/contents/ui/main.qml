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
    width: 80
    height: 20

    //height and width, when widget is placed in plasma panel
    Layout.preferredWidth: 80 * units.devicePixelRatio
    Layout.preferredHeight: 20 * units.devicePixelRatio

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    property string batPath: getBatPath()
    property bool powerNow: checkPowerNow(batPath)
    property double power: getPower(batPath)

    //this function tries to find the exact path to battery file
    function getBatPath() {
        for(var i=0; i<4; i++) {
            var path = "/sys/class/power_supply/BAT" + i + "/voltage_now";
            var req = new XMLHttpRequest();
            req.open("GET", path, false);
            req.send(null)
            if(req.responseText != "") {
                //console.log(path)
                return "/sys/class/power_supply/BAT" + i;
            }
        }
        return ""
    }

    //this function checks if the "/sys/class/power_supply/BAT[i]/power_now" file exists
    function checkPowerNow(fileUrl) {
        if(fileUrl == "") {
            return false
        }

        var path = fileUrl + "/power_now"
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

    //Returns power usage in Watts, rounded off to 1 decimal.
    function getPower(fileUrl) {
        //if there is no BAT[i] file at all
        if(fileUrl == "") {
            return "0.0"
        }

        //in case the "power_now" file exists:
        if( main.powerNow == true) {
            var path = fileUrl + "/power_now"
            var req = new XMLHttpRequest();
            req.open("GET", path, false);
            req.send(null);

            var power = parseInt(req.responseText) / 1000000;
            return(Math.round(power*10)/10);
        }

        //if the power_now file doesn't exist, we collect voltage
        //and current and manually calculate power consumption
        var curUrl = fileUrl + "/current_now"
        var voltUrl = fileUrl + "/voltage_now"

        var curReq = new XMLHttpRequest();
        var voltReq = new XMLHttpRequest();

        curReq.open("GET", curUrl, false);
        voltReq.open("GET", voltUrl, false);

        curReq.send(null);
        voltReq.send(null);

        var power = (parseInt(curReq.responseText) * parseInt(voltReq.responseText))/1000000000000;
        //console.log(power.toFixed(1));
        return Math.round(power*10)/10; //toFixed() is apparently slow, so we use this way
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
                return(main.power + ".0 W");
            }
            else {
                return(main.power + " W");
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
            main.power = getPower(main.batPath)
            if(Number.isInteger(main.power)) {
                //When power has 0 decimal places, it removes the decimal
                //point inspite of power variable being double. This momentarily
                //makes the font size bigger due to extra available space which
                //does not look good. So we do this simple hack of manually adding 
                //a .0 to number
                display.text = main.power + ".0 W";
            }
            else {
                display.text = main.power + " W"
            }
        }
    }
}
