import QtQuick
import "../../../.."
import "../../../../services"
import "." as Productivity
import "../shared" as Shared

pragma ComponentBehavior: Bound

Item {
    id: root
    clip: true
    focus: true

    readonly property date today: new Date()
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    property int viewYear: selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()
    property real entrance: 1
    property real sideOne: 1
    property real sideTwo: 1
    property real sideThree: 1
    property real zodiacDrift: 0
    property real daySpinAngle: 0
    property real monthSpinAngle: 0
    property int calendarMode: 0
    readonly property bool heliocentricMode: calendarMode === 1
    readonly property bool earthMode: calendarMode === 2
    property real celestialReveal: calendarMode === 0 ? 0 : 1
    property real heliocentricReveal: heliocentricMode ? 1 : 0
    property real earthReveal: earthMode ? 1 : 0
    property real modePulse: 1
    readonly property real calendarReturn: 1 - celestialReveal
    readonly property real calendarSupportReveal: smoothStep(Math.min(1,
        calendarReturn / 0.58))
    readonly property real calendarFaceReveal: smoothStep(Math.max(0, Math.min(1,
        (calendarReturn - 0.62) / 0.38)))
    readonly property real telemetryReveal: 1 - calendarSupportReveal
    readonly property real telemetryMerge: smoothStep(Math.min(1, telemetryReveal / 0.52))
    readonly property real telemetryAbsorb: smoothStep(Math.max(0, Math.min(1,
        (telemetryReveal - 0.48) / 0.52)))
    readonly property real telemetryFluid: Math.min(1, telemetryMerge * 3.2)
    readonly property real telemetryTextOpacity: Math.max(0, 1 - telemetryMerge * 2.15)
    property double smoothEpoch: Date.now()
    readonly property var monthNames: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    readonly property var zodiacNames: ["ARI", "TAU", "GEM", "CNC", "LEO", "VIR", "LIB", "SCO", "SGR", "CAP", "AQR", "PSC"]
    // JPL Solar System Dynamics approximate elements and rates, Table 1
    // (J2000 ecliptic, fitted for 1800—2050).
    readonly property var planets: [
        { "name": "MER", "a": 0.38709927, "da": 0.00000037, "e": 0.20563593, "de": 0.00001906, "i": 7.00497902, "di": -0.00594749, "l": 252.25032350, "dl": 149472.67411175, "p": 77.45779628, "dp": 0.16047689, "n": 48.33076593, "dn": -0.12534081 },
        { "name": "VEN", "a": 0.72333566, "da": 0.00000390, "e": 0.00677672, "de": -0.00004107, "i": 3.39467605, "di": -0.00078890, "l": 181.97909950, "dl": 58517.81538729, "p": 131.60246718, "dp": 0.00268329, "n": 76.67984255, "dn": -0.27769418 },
        { "name": "EAR", "a": 1.00000261, "da": 0.00000562, "e": 0.01671123, "de": -0.00004392, "i": -0.00001531, "di": -0.01294668, "l": 100.46457166, "dl": 35999.37244981, "p": 102.93768193, "dp": 0.32327364, "n": 0.0, "dn": 0.0 },
        { "name": "MAR", "a": 1.52371034, "da": 0.00001847, "e": 0.09339410, "de": 0.00007882, "i": 1.84969142, "di": -0.00813131, "l": -4.55343205, "dl": 19140.30268499, "p": -23.94362959, "dp": 0.44441088, "n": 49.55953891, "dn": -0.29257343 },
        { "name": "JUP", "a": 5.20288700, "da": -0.00011607, "e": 0.04838624, "de": -0.00013253, "i": 1.30439695, "di": -0.00183714, "l": 34.39644051, "dl": 3034.74612775, "p": 14.72847983, "dp": 0.21252668, "n": 100.47390909, "dn": 0.20469106 },
        { "name": "SAT", "a": 9.53667594, "da": -0.00125060, "e": 0.05386179, "de": -0.00050991, "i": 2.48599187, "di": 0.00193609, "l": 49.95424423, "dl": 1222.49362201, "p": 92.59887831, "dp": -0.41897216, "n": 113.66242448, "dn": -0.28867794 },
        { "name": "URA", "a": 19.18916464, "da": -0.00196176, "e": 0.04725744, "de": -0.00004397, "i": 0.77263783, "di": -0.00242939, "l": 313.23810451, "dl": 428.48202785, "p": 170.95427630, "dp": 0.40805281, "n": 74.01692503, "dn": 0.04240589 },
        { "name": "NEP", "a": 30.06992276, "da": 0.00026291, "e": 0.00859048, "de": 0.00005105, "i": 1.77004347, "di": 0.00035372, "l": -55.12002969, "dl": 218.45945325, "p": 44.96476227, "dp": -0.32241464, "n": 131.78422574, "dn": -0.00508664 }
    ]
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int selectedIndex: selectedDate.getDate() - 1
    readonly property int selectedZodiac: zodiacIndex(selectedDate)
    readonly property real lunarPhase: moonPhase(selectedDate)
    readonly property real lunarAge: lunarPhase * 29.53058867
    readonly property int illumination: Math.round((1 - Math.cos(lunarPhase * Math.PI * 2)) * 50)
    readonly property bool lunarCenterIsDark: Math.abs(Math.cos(lunarPhase * Math.PI * 2)) < 0.5
    readonly property var selectedForecast: forecastFor(selectedDate)
    readonly property date liveClock: new Date(smoothEpoch)
    readonly property real hours: liveClock.getHours() % 12 + liveClock.getMinutes() / 60
        + liveClock.getSeconds() / 3600 + liveClock.getMilliseconds() / 3600000
    readonly property real minutes: liveClock.getMinutes() + liveClock.getSeconds() / 60
        + liveClock.getMilliseconds() / 60000
    readonly property real seconds: liveClock.getSeconds() + liveClock.getMilliseconds() / 1000
    readonly property var todayWeather: Weather.daily.length > 0 ? Weather.daily[0] : null
    readonly property bool localDaylight: userInDaylight(liveClock)
    readonly property int localClockMinutes: liveClock.getHours() * 60 + liveClock.getMinutes()
    readonly property int sunriseMinutes: timeMinutes(todayWeather ? todayWeather.sunrise : "")
    readonly property int sunsetMinutes: timeMinutes(todayWeather ? todayWeather.sunset : "")
    readonly property real daylightProgress: sunriseMinutes >= 0 && sunsetMinutes > sunriseMinutes
        ? Math.max(0, Math.min(1, (localClockMinutes - sunriseMinutes) / (sunsetMinutes - sunriseMinutes))) : 0
    readonly property string nextSolarLabel: localDaylight ? "SUNSET" : "SUNRISE"
    readonly property string nextSolarTime: {
        if (localDaylight)
            return todayWeather ? todayWeather.sunset || "--:--" : "--:--";
        if (localClockMinutes < sunriseMinutes)
            return todayWeather ? todayWeather.sunrise || "--:--" : "--:--";
        return Weather.daily.length > 1 ? Weather.daily[1].sunrise || "--:--" : "--:--";
    }

    // Minutes until the next sunrise or sunset, wrapped across midnight.
    readonly property string untilNextSolar: {
        if (sunriseMinutes < 0 || sunsetMinutes < 0)
            return "--";
        const target = localDaylight ? sunsetMinutes : sunriseMinutes;
        let delta = target - localClockMinutes;
        if (delta < 0)
            delta += 1440;
        const hours = Math.floor(delta / 60);
        return hours > 0 ? hours + "H " + (delta % 60) + "M" : delta + "M";
    }

    function julianDate(value) {
        return Date.UTC(value.getFullYear(), value.getMonth(), value.getDate(), 12, 0, 0) / 86400000 + 2440587.5;
    }

    function orbitalElements(planet, value) {
        const centuries = (julianDate(value) - 2451545.0) / 36525;
        return {
            "a": planet.a + planet.da * centuries,
            "e": planet.e + planet.de * centuries,
            "i": (planet.i + planet.di * centuries) * Math.PI / 180,
            "l": planet.l + planet.dl * centuries,
            "p": (planet.p + planet.dp * centuries) * Math.PI / 180,
            "n": (planet.n + planet.dn * centuries) * Math.PI / 180
        };
    }

    function orbitalCoordinates(elements, eccentricAnomaly) {
        const xp = elements.a * (Math.cos(eccentricAnomaly) - elements.e);
        const yp = elements.a * Math.sqrt(1 - elements.e * elements.e) * Math.sin(eccentricAnomaly);
        const omega = elements.p - elements.n;
        const cosW = Math.cos(omega); const sinW = Math.sin(omega);
        const cosN = Math.cos(elements.n); const sinN = Math.sin(elements.n);
        const cosI = Math.cos(elements.i);
        return {
            "x": (cosW * cosN - sinW * sinN * cosI) * xp
                + (-sinW * cosN - cosW * sinN * cosI) * yp,
            "y": (cosW * sinN + sinW * cosN * cosI) * xp
                + (-sinW * sinN + cosW * cosN * cosI) * yp
        };
    }

    function planetPosition(planet, value) {
        const elements = orbitalElements(planet, value);
        let mean = ((elements.l * Math.PI / 180 - elements.p + Math.PI)
            % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
        let eccentric = mean;
        for (let iteration = 0; iteration < 9; iteration++)
            eccentric -= (eccentric - elements.e * Math.sin(eccentric) - mean)
                / (1 - elements.e * Math.cos(eccentric));
        return orbitalCoordinates(elements, eccentric);
    }

    function projectedOrbitPoint(position, span) {
        const distance = Math.sqrt(position.x * position.x + position.y * position.y);
        const radius = span * (0.070 + 0.365 * Math.log(1 + distance) / Math.log(31.2));
        const angle = Math.atan2(position.y, position.x);
        return { "x": Math.cos(angle) * radius, "y": Math.sin(angle) * radius };
    }

    function planetTone(index) {
        const physicalTones = [
            "#aaa7a2", "#d7a867", "#438bd4", "#bd5638",
            "#d2a679", "#d8c38f", "#75cbd1", "#405fc4"
        ];
        return physicalTones[index];
    }

    function planetSize(index) {
        return [9, 13, 14, 11, 23, 21, 17, 17][index];
    }

    function setCalendarMode(mode) {
        if (calendarMode === mode)
            return;
        modeTransition.stop();
        modePulse = 0;
        calendarMode = mode;
        modeTransition.restart();
    }

    function smoothStep(value) {
        return value * value * (3 - 2 * value);
    }

    function solarDirection(value) {
        const julian = value.getTime() / 86400000 + 2440587.5;
        const days = julian - 2451545.0;
        const radians = Math.PI / 180;
        const meanLongitude = (280.460 + 0.9856474 * days) * radians;
        const meanAnomaly = (357.528 + 0.9856003 * days) * radians;
        const eclipticLongitude = meanLongitude + (1.915 * Math.sin(meanAnomaly)
            + 0.020 * Math.sin(2 * meanAnomaly)) * radians;
        const obliquity = (23.439 - 0.0000004 * days) * radians;
        const declination = Math.asin(Math.sin(obliquity) * Math.sin(eclipticLongitude));
        const rightAscension = Math.atan2(Math.cos(obliquity) * Math.sin(eclipticLongitude),
            Math.cos(eclipticLongitude));
        const sidereal = (280.46061837 + 360.98564736629 * days) * radians;
        const longitude = rightAscension - sidereal;
        return {
            "x": Math.cos(declination) * Math.cos(longitude),
            "y": Math.cos(declination) * Math.sin(longitude),
            "z": Math.sin(declination)
        };
    }

    function userInDaylight(value) {
        if (!isFinite(Weather.latitude) || !isFinite(Weather.longitude))
            return false;
        const latitude = Weather.latitude * Math.PI / 180;
        const longitude = Weather.longitude * Math.PI / 180;
        const sun = solarDirection(value);
        return Math.cos(latitude) * Math.cos(longitude) * sun.x
            + Math.cos(latitude) * Math.sin(longitude) * sun.y
            + Math.sin(latitude) * sun.z >= 0;
    }

    Behavior on heliocentricReveal {
        NumberAnimation { duration: Settings.motion ? 720 : 0; easing.type: Easing.InOutCubic }
    }
    Behavior on earthReveal {
        NumberAnimation { duration: Settings.motion ? 720 : 0; easing.type: Easing.InOutCubic }
    }
    Behavior on celestialReveal {
        NumberAnimation { duration: Settings.motion ? 760 : 0; easing.type: Easing.InOutCubic }
    }

    NumberAnimation {
        id: modeTransition
        target: root; property: "modePulse"; from: 0; to: 1
        duration: Settings.motion ? 780 : 0; easing.type: Easing.OutExpo
    }

    function circularDistance(a, b, size) {
        const distance = Math.abs(a - b);
        return Math.min(distance, size - distance);
    }

    function zodiacIndex(value) {
        const stamp = (value.getMonth() + 1) * 100 + value.getDate();
        if (stamp >= 321 && stamp < 420) return 0;
        if (stamp >= 420 && stamp < 521) return 1;
        if (stamp >= 521 && stamp < 621) return 2;
        if (stamp >= 621 && stamp < 723) return 3;
        if (stamp >= 723 && stamp < 823) return 4;
        if (stamp >= 823 && stamp < 923) return 5;
        if (stamp >= 923 && stamp < 1023) return 6;
        if (stamp >= 1023 && stamp < 1122) return 7;
        if (stamp >= 1122 && stamp < 1222) return 8;
        if (stamp >= 1222 || stamp < 120) return 9;
        if (stamp < 219) return 10;
        return 11;
    }

    function moonPhase(value) {
        const epoch = Date.UTC(2000, 0, 6, 18, 14, 0);
        const instant = Date.UTC(value.getFullYear(), value.getMonth(), value.getDate(), 12, 0, 0);
        const cycles = (instant - epoch) / 86400000 / 29.53058867;
        return ((cycles % 1) + 1) % 1;
    }

    function phaseName(phase) {
        if (phase < 0.035 || phase >= 0.965) return "NEW";
        if (phase < 0.215) return "WAXING";
        if (phase < 0.285) return "FIRST QTR";
        if (phase < 0.465) return "GIBBOUS";
        if (phase < 0.535) return "FULL";
        if (phase < 0.715) return "WANING";
        if (phase < 0.785) return "LAST QTR";
        return "CRESCENT";
    }

    function selectDay(day) {
        selectedDate = new Date(viewYear, viewMonth, day);
        moonFace.requestPaint();
    }

    function selectMonth(month) {
        const normalized = ((month % 12) + 12) % 12;
        const day = Math.min(selectedDate.getDate(), new Date(viewYear, normalized + 1, 0).getDate());
        viewMonth = normalized;
        selectedDate = new Date(viewYear, normalized, day);
        moonFace.requestPaint();
    }

    function stepDays(amount) {
        const next = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + amount);
        selectedDate = next;
        viewYear = next.getFullYear();
        viewMonth = next.getMonth();
        moonFace.requestPaint();
    }

    function moveMonth(amount) {
        const target = new Date(viewYear, viewMonth + amount, 1);
        const day = Math.min(selectedDate.getDate(), new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate());
        selectedDate = new Date(target.getFullYear(), target.getMonth(), day);
        viewYear = target.getFullYear();
        viewMonth = target.getMonth();
        deploy();
    }

    function moveYear(amount) {
        const targetYear = viewYear + amount;
        const day = Math.min(selectedDate.getDate(), new Date(targetYear, viewMonth + 1, 0).getDate());
        viewYear = targetYear;
        selectedDate = new Date(targetYear, viewMonth, day);
        deploy();
    }

    function goToday() {
        selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        deploy();
    }

    function forecastFor(value) {
        const needle = (value.getDate() < 10 ? "0" : "") + value.getDate() + " " + monthNames[value.getMonth()];
        for (let index = 0; index < Weather.daily.length; index++)
            if (Weather.daily[index].date === needle) return Weather.daily[index];
        return null;
    }

    function temperature(value) {
        return value === undefined || value === null ? "--" : Math.round(Number(value)) + Weather.unitSymbol;
    }

    function timeMinutes(value) {
        const parts = String(value || "").split(":");
        if (parts.length !== 2)
            return -1;
        const hoursValue = Number(parts[0]);
        const minutesValue = Number(parts[1]);
        return isFinite(hoursValue) && isFinite(minutesValue)
            ? hoursValue * 60 + minutesValue : -1;
    }

    function deploy() {
        deployment.stop();
        entrance = 0;
        sideOne = 0;
        sideTwo = 0;
        sideThree = 0;
        deployment.restart();
        moonFace.requestPaint();
    }

    function beginDeployment() { deploy(); }
    function focusPrimary() { forceActiveFocus(); }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) stepDays(-1);
        else if (event.key === Qt.Key_Right) stepDays(1);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) moveMonth(-1);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) moveMonth(1);
        else if (event.key === Qt.Key_Home) goToday();
        else return;
        event.accepted = true;
    }

    SequentialAnimation {
        id: deployment
        ParallelAnimation {
            NumberAnimation { target: root; property: "entrance"; to: 1; duration: Settings.motion ? 780 : 0; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
            SequentialAnimation {
                PauseAnimation { duration: Settings.motion ? 170 : 0 }
                NumberAnimation { target: root; property: "sideOne"; to: 1; duration: Settings.motion ? 520 : 0; easing.type: Easing.OutBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: Settings.motion ? 280 : 0 }
                NumberAnimation { target: root; property: "sideTwo"; to: 1; duration: Settings.motion ? 560 : 0; easing.type: Easing.OutBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: Settings.motion ? 390 : 0 }
                NumberAnimation { target: root; property: "sideThree"; to: 1; duration: Settings.motion ? 620 : 0; easing.type: Easing.OutBack }
            }
        }
    }

    NumberAnimation on zodiacDrift {
        from: 0; to: 360; duration: 240000; loops: Animation.Infinite
        running: Settings.motion && root.visible && root.calendarMode === 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.calendarMode === 0
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) { root.stepDays(wheel.angleDelta.y > 0 ? -1 : 1); wheel.accepted = true; }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.56)
        z: -2
    }

    Item {
        id: watch
        width: Math.min(root.height - 18, root.width * 0.57)
        height: width
        x: 10 + root.telemetryReveal * ((root.width - width) / 2 - 10)
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.entrance
        scale: (0.42 + root.entrance * 0.58)
            * (1 - Math.sin(root.modePulse * Math.PI) * 0.045)
        rotation: (1 - root.entrance) * -120

        Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.22) }
        Rectangle {
            anchors.centerIn: parent
            width: watch.width * (0.10 + root.modePulse * 1.04)
            height: width; radius: width / 2
            color: Theme.accent
            opacity: (1 - root.modePulse) * 0.17
            z: 5
        }
        Rectangle {
            width: watch.width * 0.92; height: width; radius: width / 2; anchors.centerIn: parent
            color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.24)
            opacity: root.calendarFaceReveal
            visible: opacity > 0.01
        }
        Rectangle {
            width: watch.width * 0.73; height: width; radius: width / 2; anchors.centerIn: parent
            color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.18)
            opacity: root.calendarFaceReveal
            visible: opacity > 0.01
        }
        Rectangle {
            width: watch.width * 0.52; height: width; radius: width / 2; anchors.centerIn: parent
            color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.018)
            opacity: root.calendarFaceReveal
            visible: opacity > 0.01
        }

        Item {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.heliocentricReveal
            scale: 0.72 + root.heliocentricReveal * 0.28
                + Math.sin(root.modePulse * Math.PI) * 0.075
            z: 6

            Canvas {
                id: orbitMap
                anchors.fill: parent
                antialiasing: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    if (!root.heliocentricMode)
                        return;
                    const cx = width / 2;
                    const cy = height / 2;
                    for (let planetIndex = root.planets.length - 1; planetIndex >= 0; planetIndex--) {
                        const elements = root.orbitalElements(root.planets[planetIndex], root.selectedDate);
                        ctx.beginPath();
                        for (let sample = 0; sample <= 96; sample++) {
                            const anomaly = sample * Math.PI * 2 / 96;
                            const point = root.projectedOrbitPoint(
                                root.orbitalCoordinates(elements, anomaly), width);
                            if (sample === 0) ctx.moveTo(cx + point.x, cy + point.y);
                            else ctx.lineTo(cx + point.x, cy + point.y);
                        }
                        ctx.strokeStyle = planetIndex === 2
                            ? Theme.accent : planetIndex < 4
                                ? "rgba(218, 221, 230, 0.15)" : "rgba(218, 221, 230, 0.075)";
                        ctx.globalAlpha = planetIndex === 2 ? 0.62 : 1;
                        ctx.lineWidth = planetIndex === 2 ? 2.2 : 0.72;
                        ctx.stroke();
                        ctx.globalAlpha = 1;
                    }
                }
                Connections {
                    target: root
                    function onSelectedDateChanged() { orbitMap.requestPaint(); }
                    function onHeliocentricModeChanged() { orbitMap.requestPaint(); }
                }
                Component.onCompleted: requestPaint()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 58; height: 58; radius: width / 2
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.10)
                Rectangle {
                    anchors.centerIn: parent
                    width: 34; height: 34; radius: width / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.rose }
                        GradientStop { position: 0.48; color: Theme.warning }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    Rectangle {
                        x: parent.width * 0.24; y: parent.height * 0.18
                        width: 9; height: 9; radius: width / 2
                        color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.78)
                    }
                }
                SequentialAnimation on opacity {
                    running: Settings.motion && root.heliocentricMode
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.72; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
                }
            }

            Repeater {
                model: root.planets
                Item {
                    id: planetBody
                    required property int index
                    required property var modelData
                    readonly property var spatial: root.planetPosition(modelData, root.selectedDate)
                    readonly property var projected: root.projectedOrbitPoint(spatial, watch.width)
                    readonly property real bodySize: root.planetSize(index)
                    x: watch.width / 2 + projected.x - width / 2
                    y: watch.height / 2 + projected.y - height / 2
                    width: bodySize; height: bodySize; z: 4

                    Rectangle {
                        visible: planetBody.index === 5
                        anchors.centerIn: parent
                        width: parent.width + 18; height: 7; radius: height / 2
                        color: "#b9a778"
                        opacity: 0.72; rotation: -18; z: -2
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 5; height: parent.height - 3
                            radius: height / 2
                            color: Theme.void_
                        }
                    }
                    Rectangle {
                        visible: planetBody.index === 2 || planetBody.index >= 6
                        anchors.centerIn: parent
                        width: parent.width + 3; height: width; radius: width / 2
                        color: Qt.lighter(root.planetTone(planetBody.index), 1.45)
                        opacity: 0.54
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        clip: true
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: Qt.lighter(root.planetTone(planetBody.index), 1.48)
                            }
                            GradientStop {
                                position: 0.52
                                color: root.planetTone(planetBody.index)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.darker(root.planetTone(planetBody.index), 1.85)
                            }
                        }
                        Column {
                            visible: planetBody.index === 4 || planetBody.index === 5
                            anchors.fill: parent
                            anchors.topMargin: parent.height * 0.19
                            spacing: parent.height * 0.11
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    x: 2
                                    width: Math.max(1, planetBody.width - 4)
                                    height: Math.max(1, planetBody.height * (index === 1 ? 0.12 : 0.07))
                                    radius: height / 2
                                    color: index === 1 ? Qt.rgba(0.42, 0.20, 0.15, 0.44)
                                        : Qt.rgba(1, 0.91, 0.72, 0.28)
                                }
                            }
                        }
                        Rectangle {
                            x: parent.width * 0.18; y: parent.height * 0.14
                            width: Math.max(2, parent.width * 0.24)
                            height: width * 0.72; radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.34)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom; anchors.topMargin: 5
                        text: planetBody.modelData.name
                        color: Theme.moon
                        font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black
                        opacity: planetPointer.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: planetPointer
                        anchors.centerIn: parent
                        width: 34; height: 34
                        hoverEnabled: true
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.earthReveal
            scale: 0.72 + root.earthReveal * 0.28
                + Math.sin(root.modePulse * Math.PI) * 0.075
            z: 7

            Canvas {
                id: earthGlobe
                width: Math.round(watch.width * 0.76)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -14
                antialiasing: true

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    if (!root.earthMode)
                        return;
                    const cx = width / 2;
                    const cy = height / 2;
                    const radius = Math.min(width, height) / 2 - 3;
                    const latitude0 = (isFinite(Weather.latitude) ? Weather.latitude : 0) * Math.PI / 180;
                    const longitude0 = (isFinite(Weather.longitude) ? Weather.longitude : 0) * Math.PI / 180;

                    function projected(latitudeDegrees, longitudeDegrees) {
                        const latitude = latitudeDegrees * Math.PI / 180;
                        const longitude = longitudeDegrees * Math.PI / 180;
                        const delta = longitude - longitude0;
                        const visibility = Math.sin(latitude0) * Math.sin(latitude)
                            + Math.cos(latitude0) * Math.cos(latitude) * Math.cos(delta);
                        return {
                            "x": cx + radius * Math.cos(latitude) * Math.sin(delta),
                            "y": cy - radius * (Math.cos(latitude0) * Math.sin(latitude)
                                - Math.sin(latitude0) * Math.cos(latitude) * Math.cos(delta)),
                            "visible": visibility >= 0
                        };
                    }

                    const landmasses = [
                        [[72,-25],[72,18],[64,34],[58,30],[54,16],[50,5],[54,-9],[62,-13]],
                        [[51,-10],[46,2],[43,17],[36,27],[30,32],[24,27],[18,19],[8,13],[-4,17],[-16,26],[-29,22],[-35,11],[-29,0],[-15,-8],[2,-12],[18,-17],[34,-13]],
                        [[62,30],[67,57],[61,82],[53,102],[45,118],[34,122],[23,108],[17,84],[23,60],[34,43],[48,34]],
                        [[16,-98],[25,-118],[42,-126],[56,-116],[67,-92],[62,-68],[48,-60],[32,-78]],
                        [[10,-79],[-4,-77],[-19,-69],[-35,-58],[-53,-68],[-43,-75],[-22,-82]],
                        [[-11,112],[-17,132],[-29,151],[-43,146],[-39,116]]
                    ];

                    ctx.save();
                    ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.clip();
                    const ocean = ctx.createRadialGradient(cx - radius * 0.26,
                        cy - radius * 0.30, radius * 0.08, cx, cy, radius * 1.08);
                    ocean.addColorStop(0, "#4c9bd8");
                    ocean.addColorStop(0.62, "#246ba8");
                    ocean.addColorStop(1, "#123b69");
                    ctx.fillStyle = ocean;
                    ctx.fillRect(cx - radius, cy - radius, radius * 2, radius * 2);

                    ctx.fillStyle = "rgba(128, 174, 108, 0.58)";
                    ctx.strokeStyle = "rgba(210, 232, 190, 0.30)";
                    ctx.lineWidth = 1.4;
                    for (let mass = 0; mass < landmasses.length; mass++) {
                        const points = [];
                        for (let vertex = 0; vertex < landmasses[mass].length; vertex++) {
                            const coordinate = landmasses[mass][vertex];
                            const point = projected(coordinate[0], coordinate[1]);
                            if (point.visible)
                                points.push(point);
                        }
                        // Never bridge a hidden hemisphere with the enormous
                        // straight polygons the old globe occasionally drew.
                        if (points.length !== landmasses[mass].length)
                            continue;
                        ctx.beginPath();
                        const last = points[points.length - 1];
                        ctx.moveTo((last.x + points[0].x) / 2,
                            (last.y + points[0].y) / 2);
                        for (let pointIndex = 0; pointIndex < points.length; pointIndex++) {
                            const point = points[pointIndex];
                            const next = points[(pointIndex + 1) % points.length];
                            ctx.quadraticCurveTo(point.x, point.y,
                                (point.x + next.x) / 2, (point.y + next.y) / 2);
                        }
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();
                    }

                    const sun = root.solarDirection(root.liveClock);
                    const sinLat = Math.sin(latitude0); const cosLat = Math.cos(latitude0);
                    const sinLon = Math.sin(longitude0); const cosLon = Math.cos(longitude0);
                    const center = [cosLat * cosLon, cosLat * sinLon, sinLat];
                    const east = [-sinLon, cosLon, 0];
                    const north = [-sinLat * cosLon, -sinLat * sinLon, cosLat];
                    const sunEast = sun.x * east[0] + sun.y * east[1] + sun.z * east[2];
                    const sunNorth = -(sun.x * north[0] + sun.y * north[1] + sun.z * north[2]);
                    const sunForward = sun.x * center[0] + sun.y * center[1] + sun.z * center[2];
                    const screenMagnitude = Math.sqrt(sunEast * sunEast + sunNorth * sunNorth);

                    if (screenMagnitude < 0.0001) {
                        if (sunForward < 0) {
                            ctx.fillStyle = "rgba(3, 5, 16, 0.82)";
                            ctx.fillRect(cx - radius, cy - radius, radius * 2, radius * 2);
                        }
                    } else {
                        const ux = -sunNorth / screenMagnitude;
                        const uy = sunEast / screenMagnitude;
                        const vx = -sunForward * uy;
                        const vy = sunForward * ux;
                        const samples = 72;
                        ctx.beginPath();
                        for (let sample = 0; sample <= samples; sample++) {
                            const angle = sample * Math.PI / samples;
                            const px = cx + radius * (ux * Math.cos(angle) + vx * Math.sin(angle));
                            const py = cy + radius * (uy * Math.cos(angle) + vy * Math.sin(angle));
                            if (sample === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }

                        const limbStart = Math.atan2(-uy, -ux);
                        const positiveMid = limbStart + Math.PI / 2;
                        const positiveIsNight = sunEast * Math.cos(positiveMid)
                            + sunNorth * Math.sin(positiveMid) < 0;
                        const direction = positiveIsNight ? Math.PI : -Math.PI;
                        for (let sample = 1; sample <= samples; sample++) {
                            const angle = limbStart + direction * sample / samples;
                            ctx.lineTo(cx + radius * Math.cos(angle), cy + radius * Math.sin(angle));
                        }
                        ctx.closePath();
                        ctx.fillStyle = "rgba(3, 5, 16, 0.78)";
                        ctx.fill();

                        ctx.beginPath();
                        for (let sample = 0; sample <= samples; sample++) {
                            const angle = sample * Math.PI / samples;
                            const px = cx + radius * (ux * Math.cos(angle) + vx * Math.sin(angle));
                            const py = cy + radius * (uy * Math.cos(angle) + vy * Math.sin(angle));
                            if (sample === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }
                        ctx.strokeStyle = "rgba(255, 220, 160, 0.22)";
                        ctx.lineWidth = 2;
                        ctx.stroke();
                    }

                    const rim = ctx.createRadialGradient(cx, cy, radius * 0.70,
                        cx, cy, radius);
                    rim.addColorStop(0, "rgba(3, 5, 16, 0)");
                    rim.addColorStop(1, "rgba(3, 5, 16, 0.34)");
                    ctx.fillStyle = rim;
                    ctx.fillRect(cx - radius, cy - radius, radius * 2, radius * 2);
                    ctx.restore();

                    ctx.strokeStyle = "rgba(226, 232, 240, 0.58)";
                    ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.stroke();
                    ctx.fillStyle = "#ff6b6b";
                    ctx.beginPath(); ctx.arc(cx, cy, 6, 0, Math.PI * 2); ctx.fill();
                    ctx.fillStyle = "#fff4df";
                    ctx.beginPath(); ctx.arc(cx, cy, 2.2, 0, Math.PI * 2); ctx.fill();
                }

                Connections {
                    target: root
                    function onEarthModeChanged() { earthGlobe.requestPaint(); }
                }
                Connections {
                    target: Weather
                    function onLatitudeChanged() { earthGlobe.requestPaint(); }
                    function onLongitudeChanged() { earthGlobe.requestPaint(); }
                }
                Timer {
                    interval: 60000; repeat: true; triggeredOnStart: true
                    running: root.earthMode && root.visible
                    onTriggered: earthGlobe.requestPaint()
                }
                Component.onCompleted: {
                    if (root.earthMode)
                        requestPaint();
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                spacing: 5
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.earthMode ? (root.localDaylight ? "DAY  /  " : "NIGHT  /  ")
                        + root.nextSolarLabel + "  " + root.nextSolarTime : ""
                    color: root.localDaylight ? Theme.warning : Theme.accent
                    font.family: Theme.fontMono; font.pixelSize: 12; font.weight: Font.Black
                    font.letterSpacing: 1.5
                }
                Canvas {
                    id: daylightLine
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220; height: 8; antialiasing: true
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.clearRect(0, 0, width, height);
                        ctx.lineCap = "round";
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = "rgba(238, 233, 220, 0.12)";
                        ctx.beginPath(); ctx.moveTo(2, height / 2); ctx.lineTo(width - 2, height / 2); ctx.stroke();
                        if (!root.localDaylight)
                            return;
                        const stop = 2 + (width - 4) * root.daylightProgress;
                        ctx.strokeStyle = Theme.warning;
                        ctx.beginPath(); ctx.moveTo(2, height / 2); ctx.lineTo(stop, height / 2); ctx.stroke();
                        ctx.fillStyle = Theme.moon;
                        ctx.beginPath(); ctx.arc(stop, height / 2, 3, 0, Math.PI * 2); ctx.fill();
                    }
                    Connections {
                        target: root
                        function onDaylightProgressChanged() { daylightLine.requestPaint(); }
                        function onEarthModeChanged() { daylightLine.requestPaint(); }
                    }
                    Component.onCompleted: requestPaint()
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.location.length ? Weather.location.toUpperCase() : "LOCATION UNRESOLVED"
                    color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
            }
        }

        Repeater {
            model: root.calendarFaceReveal > 0.001 ? 60 : 0
            Rectangle {
                required property int index
                readonly property real angle: index * Math.PI * 2 / 60 - Math.PI / 2
                width: index % 5 === 0 ? 6 : 2; height: width; radius: width / 2
                x: watch.width / 2 + Math.cos(angle) * watch.width * 0.462 - width / 2
                y: watch.height / 2 + Math.sin(angle) * watch.height * 0.462 - height / 2
                color: index % 5 === 0 ? Theme.moon : Theme.muted
                opacity: (index % 5 === 0 ? 0.72 : 0.24) * root.calendarFaceReveal
                scale: 0.72 + root.calendarFaceReveal * 0.28
            }
        }

        Repeater {
            model: root.calendarFaceReveal > 0.001 ? 12 : 0
            Item {
                id: zodiac
                required property int index
                readonly property bool selected: index === root.selectedZodiac
                readonly property int distance: root.circularDistance(index, root.selectedZodiac, 12)
                readonly property real angle: ((index - root.selectedZodiac) * 30
                    + Math.sin(root.zodiacDrift * Math.PI / 180) * 1.5 - 90) * Math.PI / 180
                width: selected ? 42 : 34; height: selected ? 24 : 20
                x: watch.width / 2 + Math.cos(angle) * watch.width * 0.425 - width / 2
                y: watch.height / 2 + Math.sin(angle) * watch.height * 0.425 - height / 2
                z: selected ? 7 : 2
                opacity: root.calendarFaceReveal
                scale: 0.76 + root.calendarFaceReveal * 0.24
                Behavior on width { enabled: Settings.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: Settings.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Rectangle {
                    visible: zodiac.selected
                    anchors.fill: parent; radius: height / 2
                    color: Theme.rose
                }
                Text {
                    anchors.centerIn: parent; text: root.zodiacNames[zodiac.index]
                    color: zodiac.selected ? Theme.void_ : Theme.muted
                    font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black
                    visible: zodiac.selected || zodiac.distance === 1
                    opacity: zodiac.selected ? 1 : 0.46
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 2
                    visible: zodiac.distance > 1
                    color: Theme.muted; opacity: 0.26
                }
            }
        }

        Repeater {
            model: root.calendarFaceReveal > 0.001 ? 12 : 0
            Item {
                id: monthMark
                required property int index
                readonly property int distance: root.circularDistance(index, root.viewMonth, 12)
                readonly property bool current: root.viewYear === root.today.getFullYear()
                    && index === root.today.getMonth()
                readonly property real angle: ((index - root.viewMonth) * 30 - 90) * Math.PI / 180
                    + root.monthSpinAngle
                width: index === root.viewMonth ? 36 : 28; height: width
                x: watch.width / 2 + Math.cos(angle) * watch.width * 0.325 - width / 2
                y: watch.height / 2 + Math.sin(angle) * watch.height * 0.325 - height / 2
                Behavior on x { enabled: Settings.motion && ringSpinner.activeRing !== "month"; NumberAnimation { duration: 470; easing.type: Easing.OutBack; easing.overshoot: 1.10 } }
                Behavior on y { enabled: Settings.motion && ringSpinner.activeRing !== "month"; NumberAnimation { duration: 470; easing.type: Easing.OutBack; easing.overshoot: 1.10 } }
                opacity: root.calendarFaceReveal
                scale: 0.72 + root.calendarFaceReveal * 0.28
                Behavior on width { enabled: Settings.motion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: Settings.motion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: monthMark.current ? Theme.cyan
                        : monthMark.index === root.viewMonth ? Theme.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent; text: root.monthNames[monthMark.index]
                    color: monthMark.current || monthMark.index === root.viewMonth ? Theme.void_ : Theme.muted
                    font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black
                    visible: monthMark.index === root.viewMonth || monthMark.current || monthMark.distance <= 1
                    opacity: monthMark.index === root.viewMonth ? 1 : 0.58
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 2
                    visible: monthMark.distance > 1 && !monthMark.current
                    color: Theme.muted; opacity: 0.22
                }
            }
        }

        Repeater {
            model: root.calendarFaceReveal > 0.001 ? root.daysInMonth : 0
            Item {
                id: dayMark
                required property int index
                readonly property int day: index + 1
                readonly property int distance: root.circularDistance(index, root.selectedIndex, root.daysInMonth)
                readonly property bool chosen: day === root.selectedDate.getDate()
                readonly property bool isToday: root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth() && day === root.today.getDate()
                readonly property real angle: ((index - root.selectedIndex) * 360 / root.daysInMonth - 90) * Math.PI / 180
                    + root.daySpinAngle
                width: chosen ? 36 : isToday ? 28 : 20; height: width
                x: watch.width / 2 + Math.cos(angle) * watch.width * 0.220 - width / 2
                y: watch.height / 2 + Math.sin(angle) * watch.height * 0.220 - height / 2
                z: chosen ? 8 : 3
                opacity: root.calendarFaceReveal
                scale: 0.68 + root.calendarFaceReveal * 0.32
                Behavior on x { enabled: Settings.motion && ringSpinner.activeRing !== "day"; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                Behavior on y { enabled: Settings.motion && ringSpinner.activeRing !== "day"; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                Behavior on width { enabled: Settings.motion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: Settings.motion; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: dayMark.isToday ? Theme.cyan : dayMark.chosen ? Theme.accent
                        : dayPointer.containsMouse ? Theme.controlHover : "transparent"
                }
                Text {
                    anchors.centerIn: parent; text: dayMark.day
                    color: dayMark.chosen || dayMark.isToday ? Theme.void_ : Theme.moon
                    font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black
                    visible: dayMark.chosen || dayMark.isToday || dayMark.distance <= 5
                    opacity: dayMark.chosen || dayMark.isToday ? 1 : dayMark.distance <= 2 ? 0.84 : 0.42
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 2; height: 2; radius: 1
                    visible: dayMark.distance > 5 && !dayMark.isToday
                    color: Theme.muted; opacity: 0.16
                }
                MouseArea {
                    id: dayPointer
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectDay(dayMark.day)
                }
            }
        }

        Canvas {
            id: liquidHands
            anchors.fill: parent
            z: 10
            antialiasing: true
            opacity: root.calendarFaceReveal
            visible: opacity > 0.01

            // A rounded base that tapers to a point. Drawn as one filled path:
            // stroking it with a round cap would dome the tip, and the domed
            // tip is what read as a circle stuck on the end of each hand.
            // A marker that rides the rim outside the dial and points inward:
            // a shallow arc cap following the circle, with a blade descending
            // from its middle toward the centre. Hour, minute, and second
            // share one lane and are told apart by span, weight, and reach.
            function drawRimMarker(ctx, degrees, radius, thickness, blade, spanDegrees, tone) {
                const angle = (degrees - 90) * Math.PI / 180;
                const cx = width / 2;
                const cy = height / 2;
                const half = spanDegrees * Math.PI / 180 / 2;
                const bladeHalf = half * 0.32;
                const cap = thickness / 2;
                const outer = radius + cap;
                const inner = radius - cap;
                const tip = inner - blade;

                ctx.fillStyle = tone;
                ctx.beginPath();
                // Outer edge of the cap, swept along the rim.
                ctx.arc(cx, cy, outer, angle - half, angle + half);
                // Round the trailing end with a half turn about its
                // mid-thickness point, so the cap reads as a bar bent along
                // the rim rather than one sliced off square.
                ctx.arc(cx + Math.cos(angle + half) * radius,
                    cy + Math.sin(angle + half) * radius,
                    cap, angle + half, angle + half + Math.PI);
                // Back along the inside to where the blade begins. Each arc
                // implicitly draws a line from the previous point, which
                // closes the blade's flanks.
                ctx.arc(cx, cy, inner, angle + half, angle + bladeHalf, true);
                ctx.lineTo(cx + Math.cos(angle) * tip, cy + Math.sin(angle) * tip);
                ctx.arc(cx, cy, inner, angle - bladeHalf, angle - half, true);
                ctx.arc(cx + Math.cos(angle - half) * radius,
                    cy + Math.sin(angle - half) * radius,
                    cap, angle - half + Math.PI, angle - half + Math.PI * 2);
                ctx.closePath();
                ctx.fill();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                // One lane outside the zodiac ring at 0.462. The markers
                // breathe a fraction of a pixel outward so the rim stays alive
                // without the blades wandering off their reading.
                const pulse = Math.sin(root.seconds * Math.PI / 30);
                const lane = width * 0.487;
                drawRimMarker(ctx, root.hours * 30, lane + pulse * 0.8, 5.0, 15, 15, Theme.cyan);
                drawRimMarker(ctx, root.minutes * 6, lane - pulse * 0.6, 3.8, 11, 10.5, Theme.accent);
                drawRimMarker(ctx, root.seconds * 6, lane + pulse * 1.1, 2.6, 8, 7, Theme.rose);
            }
            Connections {
                target: root
                enabled: root.calendarMode === 0
                function onSmoothEpochChanged() { liquidHands.requestPaint(); }
            }
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: ringSpinner
            anchors.fill: parent
            z: 15
            enabled: root.calendarMode === 0 && root.calendarFaceReveal > 0.98
            visible: root.calendarFaceReveal > 0.01
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property string activeRing: ""
            property real pressAngle: 0
            property real lastAngle: 0
            property real cumulativeAngle: 0
            property int pressDay: 1
            property int pressMonth: 0
            property int pendingSteps: 0

            function pointerAngle(mouse) {
                return Math.atan2(mouse.y - height / 2, mouse.x - width / 2);
            }

            onPressed: function(mouse) {
                const dx = mouse.x - width / 2;
                const dy = mouse.y - height / 2;
                const radius = Math.sqrt(dx * dx + dy * dy) / width;
                if (radius >= 0.18 && radius <= 0.275)
                    activeRing = "day";
                else if (radius >= 0.285 && radius <= 0.35)
                    activeRing = "month";
                else {
                    activeRing = "";
                    mouse.accepted = false;
                    return;
                }
                pressAngle = pointerAngle(mouse);
                lastAngle = pressAngle;
                cumulativeAngle = 0;
                pressDay = root.selectedDate.getDate();
                pressMonth = root.viewMonth;
                pendingSteps = 0;
                settleDay.stop();
                settleMonth.stop();
                root.daySpinAngle = 0;
                root.monthSpinAngle = 0;
            }

            onPositionChanged: function(mouse) {
                if (!pressed || !activeRing.length) return;
                const angle = pointerAngle(mouse);
                let movement = angle - lastAngle;
                while (movement > Math.PI) movement -= Math.PI * 2;
                while (movement < -Math.PI) movement += Math.PI * 2;
                cumulativeAngle += movement;
                lastAngle = angle;
                const delta = cumulativeAngle;
                if (activeRing === "day") {
                    root.daySpinAngle = delta;
                    pendingSteps = Math.round(delta / (Math.PI * 2 / root.daysInMonth));
                } else {
                    root.monthSpinAngle = delta;
                    pendingSteps = Math.round(delta / (Math.PI * 2 / 12));
                }
            }

            onReleased: function() {
                const ring = activeRing;
                const steps = pendingSteps;
                activeRing = "";
                if (ring === "day") {
                    const stepAngle = Math.PI * 2 / root.daysInMonth;
                    const residual = root.daySpinAngle - steps * stepAngle;
                    const day = ((pressDay - 1 - steps) % root.daysInMonth + root.daysInMonth) % root.daysInMonth + 1;
                    root.selectDay(day);
                    root.daySpinAngle = residual;
                    settleDay.restart();
                } else if (ring === "month") {
                    const stepAngle = Math.PI * 2 / 12;
                    const residual = root.monthSpinAngle - steps * stepAngle;
                    root.selectMonth(pressMonth - steps);
                    root.monthSpinAngle = residual;
                    settleMonth.restart();
                }
            }
            onCanceled: {
                activeRing = "";
                settleDay.restart();
                settleMonth.restart();
            }
        }

        NumberAnimation {
            id: settleDay
            target: root; property: "daySpinAngle"; to: 0
            duration: Settings.motion ? 150 : 0; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: settleMonth
            target: root; property: "monthSpinAngle"; to: 0
            duration: Settings.motion ? 150 : 0; easing.type: Easing.OutCubic
        }

        Item {
            id: moon
            width: watch.width * 0.22; height: width; anchors.centerIn: parent; z: 20
            opacity: root.calendarFaceReveal
            visible: opacity > 0.01
            Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.mantle }
            Canvas {
                id: moonFace
                anchors.fill: parent; anchors.margins: 7; antialiasing: true
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    const radius = width / 2;
                    ctx.save();
                    ctx.beginPath(); ctx.arc(radius, radius, radius, 0, Math.PI * 2); ctx.clip();
                    ctx.fillStyle = Theme.moon; ctx.beginPath(); ctx.arc(radius, radius, radius, 0, Math.PI * 2); ctx.fill();
                    const offset = Math.cos(root.lunarPhase * Math.PI * 2) * width;
                    ctx.fillStyle = Theme.void_; ctx.beginPath(); ctx.arc(radius + offset, radius, radius, 0, Math.PI * 2); ctx.fill();
                    ctx.restore();
                }
                Connections { target: root; function onSelectedDateChanged() { moonFace.requestPaint(); } }
                Component.onCompleted: requestPaint()
            }
            Column {
                anchors.centerIn: parent; width: parent.width * 0.72; spacing: -1
                Text {
                    width: parent.width; text: root.selectedDate.getDate()
                    color: root.lunarCenterIsDark ? Theme.moon : Theme.void_
                    font.family: Theme.fontDisplay; font.pixelSize: 28; font.weight: Font.Black; horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width; text: root.phaseName(root.lunarPhase)
                    color: root.lunarCenterIsDark ? Theme.moon : Theme.void_
                    font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black; horizontalAlignment: Text.AlignHCenter
                }
            }
            SequentialAnimation {
                id: moonPulse
                NumberAnimation { target: moon; property: "scale"; to: 1.085; duration: Settings.motion ? 150 : 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: moon; property: "scale"; to: 1; duration: Settings.motion ? 430 : 0; easing.type: Easing.OutElastic; easing.amplitude: 0.35 }
            }
            Connections {
                target: root
                function onSelectedDateChanged() { moonPulse.restart(); }
            }
        }

    }

    Item {
        id: complications
        anchors.left: parent.left; anchors.leftMargin: 38 + watch.width
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom

        Item {
            x: 8 + (1 - root.sideOne) * 160
                + (1 - root.calendarSupportReveal) * 72; y: 34
            width: 260; height: 100
            opacity: root.sideOne * root.calendarSupportReveal
            scale: (0.55 + root.sideOne * 0.45)
                * (0.86 + root.calendarSupportReveal * 0.14)
            visible: opacity > 0.01
            Text {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: root.monthNames[root.viewMonth]
                color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: Math.min(62, parent.width * 0.22)
                font.weight: Font.Black; font.letterSpacing: -2
            }
            Text {
                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                text: root.viewYear + "  /  " + Qt.formatDate(root.selectedDate, "ddd").toUpperCase()
                color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Black; font.letterSpacing: 3
            }
        }

        Row {
            anchors.left: parent.left; anchors.leftMargin: 208
            anchors.top: parent.top; anchors.topMargin: 54; spacing: 7
            opacity: root.calendarSupportReveal
            visible: opacity > 0.01
            transform: Translate { y: (1 - root.calendarSupportReveal) * -18 }
            Repeater {
                model: [{ "glyph": "‹", "delta": -1 }, { "glyph": "●", "delta": 0 }, { "glyph": "›", "delta": 1 }]
                Rectangle {
                    id: navButton
                    required property var modelData
                    width: modelData.delta === 0 ? 32 : 46; height: 32; radius: height / 2
                    color: navPointer.containsMouse ? Theme.accent : Theme.controlRest
                    Text {
                        anchors.centerIn: parent; text: navButton.modelData.glyph
                        color: navPointer.containsMouse ? Theme.void_ : Theme.moon
                        font.family: Theme.fontDisplay; font.pixelSize: navButton.modelData.delta === 0 ? 8 : 21; font.weight: Font.Black
                    }
                    MouseArea {
                        id: navPointer
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: navButton.modelData.delta === 0 ? root.goToday() : root.moveYear(navButton.modelData.delta)
                    }
                }
            }
        }

        // The sun's path for today, filling the band the complications left
        // empty. Sunrise and sunset are already resolved for Earth mode; the
        // calendar never showed them.
        Item {
            x: complications.width * 0.06
            y: complications.height * 0.72 + (1 - root.calendarSupportReveal) * 40
            width: complications.width * 0.88
            height: complications.height * 0.20
            opacity: root.sideThree * root.calendarSupportReveal
            visible: opacity > 0.01 && root.sunriseMinutes >= 0

            Canvas {
                id: solarCanvas
                anchors.fill: parent
                anchors.topMargin: 18
                anchors.bottomMargin: 20
                antialiasing: true

                function domeY(fraction) {
                    return height - Math.sin(Math.max(0, Math.min(1, fraction)) * Math.PI)
                        * (height - 8);
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const horizon = height;

                    ctx.beginPath();
                    ctx.moveTo(0, horizon);
                    ctx.lineTo(width, horizon);
                    ctx.strokeStyle = Qt.rgba(Theme.lineBright.r, Theme.lineBright.g,
                        Theme.lineBright.b, 0.34);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // Whole arc, drawn faint, then the travelled part over it.
                    for (let pass = 0; pass < 2; pass++) {
                        const limit = pass === 0 ? 1 : root.daylightProgress;
                        if (limit <= 0)
                            continue;
                        ctx.beginPath();
                        for (let step = 0; step <= 72; step++) {
                            const fraction = step / 72 * limit;
                            const x = fraction * width;
                            const y = domeY(fraction);
                            if (step === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = pass === 0
                            ? Qt.rgba(Theme.lineBright.r, Theme.lineBright.g,
                                Theme.lineBright.b, 0.28)
                            : Theme.warning;
                        ctx.lineWidth = pass === 0 ? 1.5 : 2.4;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    if (root.daylightProgress > 0 && root.daylightProgress < 1) {
                        const sx = root.daylightProgress * width;
                        const sy = domeY(root.daylightProgress);
                        ctx.beginPath();
                        ctx.arc(sx, sy, 11, 0, Math.PI * 2);
                        ctx.fillStyle = Qt.rgba(Theme.warning.r, Theme.warning.g,
                            Theme.warning.b, 0.18);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.arc(sx, sy, 5.5, 0, Math.PI * 2);
                        ctx.fillStyle = Theme.warning;
                        ctx.fill();
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: root
                    function onDaylightProgressChanged() { solarCanvas.requestPaint(); }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: "SUNRISE  " + (root.todayWeather ? root.todayWeather.sunrise || "--:--" : "--:--")
                color: Theme.muted
                font.family: Theme.fontMono; font.pixelSize: 10
                font.weight: Font.Bold; font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                text: root.localDaylight ? "DAYLIGHT" : "NIGHT"
                color: root.localDaylight ? Theme.warning : Theme.accent
                font.family: Theme.fontMono; font.pixelSize: 10
                font.weight: Font.Black; font.letterSpacing: 1.6
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: "SUNSET  " + (root.todayWeather ? root.todayWeather.sunset || "--:--" : "--:--")
                color: Theme.muted
                font.family: Theme.fontMono; font.pixelSize: 10
                font.weight: Font.Bold; font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: root.nextSolarLabel + " IN " + root.untilNextSolar
                color: Theme.muted
                font.family: Theme.fontMono; font.pixelSize: 10
                font.weight: Font.Bold
            }
        }

        Shared.WeatherRibbon {
            x: complications.width * 0.58 + (1 - root.sideThree) * 250
                + (1 - root.calendarSupportReveal) * 92
            y: complications.height * 0.27
            width: complications.width * 0.39; height: complications.height * 0.42
            opacity: root.sideThree * root.calendarSupportReveal
            scale: (0.58 + root.sideThree * 0.42)
                * (0.9 + root.calendarSupportReveal * 0.1)
            visible: opacity > 0.01
            forecast: Weather.daily
            unitSymbol: Weather.unitSymbol
            selectedIndex: Math.max(0, Math.min(dayCount - 1,
                Math.round((root.selectedDate.getTime() - root.today.getTime()) / 86400000)))
            onDayActivated: function(index) {
                root.selectedDate = new Date(root.today.getFullYear(), root.today.getMonth(),
                    root.today.getDate() + index);
                root.viewYear = root.selectedDate.getFullYear();
                root.viewMonth = root.selectedDate.getMonth();
            }
        }
    }

    Item {
        id: telemetryLayer
        anchors.fill: parent
        z: 12
        readonly property real restingComplicationX: 10 + watch.width + 28
        readonly property real restingComplicationWidth: root.width - restingComplicationX
        readonly property real hubX: root.width * 0.625
        readonly property real hubY: root.height * 0.335
        readonly property real absorbX: watch.x + watch.width * 0.5
        readonly property real absorbY: watch.y + watch.height * 0.5
        readonly property real blobX: hubX + (absorbX - hubX) * root.telemetryAbsorb
        readonly property real blobY: hubY + (absorbY - hubY) * root.telemetryAbsorb
        readonly property real fieldLeft: Math.max(0, Math.min(absorbX,
            lunarBubble.restingX + lunarBubble.width / 2,
            lightBubble.restingX + lightBubble.width / 2,
            currentSky.restingX + currentSky.width / 2) - 150)
        readonly property real fieldTop: Math.max(0, Math.min(absorbY,
            lunarBubble.restingY + lunarBubble.height / 2,
            lightBubble.restingY + lightBubble.height / 2,
            currentSky.restingY + currentSky.height / 2) - 150)
        readonly property real fieldRight: Math.min(root.width, Math.max(absorbX,
            lunarBubble.restingX + lunarBubble.width / 2,
            lightBubble.restingX + lightBubble.width / 2,
            currentSky.restingX + currentSky.width / 2) + 150)
        readonly property real fieldBottom: Math.min(root.height, Math.max(absorbY,
            lunarBubble.restingY + lunarBubble.height / 2,
            lightBubble.restingY + lightBubble.height / 2,
            currentSky.restingY + currentSky.height / 2) + 150)
        readonly property bool shaderReady: telemetryMetaballs.status === ShaderEffect.Compiled
            && GraphicsInfo.api !== GraphicsInfo.Software
        visible: root.calendarMode === 0 || root.celestialReveal < 0.999

        ShaderEffect {
            id: telemetryMetaballs
            x: telemetryLayer.fieldLeft
            y: telemetryLayer.fieldTop
            width: Math.max(1, telemetryLayer.fieldRight - x)
            height: Math.max(1, telemetryLayer.fieldBottom - y)
            z: 1
            visible: telemetryLayer.shaderReady && opacity > 0.001
            opacity: root.telemetryFluid * (1 - root.telemetryAbsorb)
            blending: true

            property size fieldSize: Qt.size(width, height)
            property vector4d balls12: Qt.vector4d(
                (lunarBubble.x + lunarBubble.width / 2 - x) / width,
                (lunarBubble.y + lunarBubble.height / 2 - y) / height,
                (lightBubble.x + lightBubble.width / 2 - x) / width,
                (lightBubble.y + lightBubble.height / 2 - y) / height)
            property vector4d ball3Radii: Qt.vector4d(
                (currentSky.x + currentSky.width / 2 - x) / width,
                (currentSky.y + currentSky.height / 2 - y) / height,
                lunarBubble.width * lunarBubble.scale * 0.5 * (1 + root.telemetryMerge * 0.17),
                lightBubble.width * lightBubble.scale * 0.5 * (1 + root.telemetryMerge * 0.17))
            property color color1: Theme.cyan
            property color color2: Theme.accent
            property color color3: Theme.moon
            property real phase: root.telemetryMerge * 6.2 + root.telemetryAbsorb * 4.1
            property real distortion: Settings.motion
                ? Math.sin(root.telemetryMerge * Math.PI) * (1 - root.telemetryAbsorb) : 0

            fragmentShader: "shaders/telemetry-metaballs.frag.qsb"
        }

        Item {
            id: lunarBubble
            readonly property real restingX: telemetryLayer.restingComplicationX
                + telemetryLayer.restingComplicationWidth * 0.05
            readonly property real restingY: root.height * 0.25
            x: restingX + (telemetryLayer.blobX - width / 2 - restingX) * root.telemetryMerge
                - (1 - root.sideTwo) * 90
            y: restingY + (telemetryLayer.blobY - height / 2 - restingY) * root.telemetryMerge
            width: 104; height: 104
            opacity: root.sideTwo * (1 - root.telemetryAbsorb)
                * (telemetryLayer.shaderReady ? 1 : 1 - root.telemetryMerge)
            scale: (0.45 + root.sideTwo * 0.55) * (1 - root.telemetryAbsorb * 0.82)
            visible: opacity > 0.01
            z: 2
            transform: Translate { id: lunarDrift }
            Rectangle {
                anchors.fill: parent; radius: width / 2; color: Theme.cyan
                opacity: telemetryLayer.shaderReady ? 1 - root.telemetryFluid : 1
            }
            Column {
                anchors.centerIn: parent; spacing: 1; opacity: root.telemetryTextOpacity
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.lunarAge.toFixed(1); color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 26; font.weight: Font.Black }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "LUNAR DAYS"; color: Theme.void_; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 2 }
            }
            SequentialAnimation {
                loops: Animation.Infinite
                running: Settings.motion && lunarBubble.visible && root.sideTwo > 0.99 && root.telemetryMerge < 0.01
                ParallelAnimation {
                    NumberAnimation { target: lunarDrift; property: "x"; to: 5; duration: 1900; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lunarDrift; property: "y"; to: -4; duration: 1900; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: lunarDrift; property: "x"; to: -4; duration: 2300; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lunarDrift; property: "y"; to: 3; duration: 2300; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: lunarDrift; property: "x"; to: 0; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lunarDrift; property: "y"; to: 0; duration: 1600; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            id: lightBubble
            readonly property real restingX: telemetryLayer.restingComplicationX
                + telemetryLayer.restingComplicationWidth * 0.24
            readonly property real restingY: root.height * 0.25 + 12
            x: restingX + (telemetryLayer.blobX - width / 2 - restingX) * root.telemetryMerge
                + (1 - root.sideTwo) * 110
            y: restingY + (telemetryLayer.blobY - height / 2 - restingY) * root.telemetryMerge
            width: 80; height: 80
            opacity: root.sideTwo * (1 - root.telemetryAbsorb)
                * (telemetryLayer.shaderReady ? 1 : 1 - root.telemetryMerge)
            scale: (0.45 + root.sideTwo * 0.55) * (1 - root.telemetryAbsorb * 0.82)
            visible: opacity > 0.01
            z: 2
            transform: Translate { id: lightDrift }
            Rectangle {
                anchors.fill: parent; radius: width / 2; color: Theme.accent
                opacity: telemetryLayer.shaderReady ? 1 - root.telemetryFluid : 1
            }
            Column {
                anchors.centerIn: parent; spacing: 1; opacity: root.telemetryTextOpacity
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.illumination + "%"; color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 22; font.weight: Font.Black }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MOONLIGHT"; color: Theme.void_; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black }
            }
            SequentialAnimation {
                loops: Animation.Infinite
                running: Settings.motion && lightBubble.visible && root.sideTwo > 0.99 && root.telemetryMerge < 0.01
                ParallelAnimation {
                    NumberAnimation { target: lightDrift; property: "x"; to: -4; duration: 2100; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lightDrift; property: "y"; to: 4; duration: 2100; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: lightDrift; property: "x"; to: 4; duration: 1700; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lightDrift; property: "y"; to: -3; duration: 1700; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: lightDrift; property: "x"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { target: lightDrift; property: "y"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            id: currentSky
            readonly property var primary: root.selectedForecast
                || (Weather.daily.length > 0 ? Weather.daily[0] : null)
            readonly property real restingX: telemetryLayer.restingComplicationX
                + telemetryLayer.restingComplicationWidth * 0.435 - width / 2
            readonly property real restingY: root.height * 0.25 + 4
            x: restingX + (telemetryLayer.blobX - width / 2 - restingX) * root.telemetryMerge
                + (1 - root.sideThree) * 150
            y: restingY + (telemetryLayer.blobY - height / 2 - restingY) * root.telemetryMerge
            width: 96; height: 96
            opacity: root.sideThree * (1 - root.telemetryAbsorb)
                * (telemetryLayer.shaderReady ? 1 : 1 - root.telemetryMerge)
            scale: (0.58 + root.sideThree * 0.42) * (1 - root.telemetryAbsorb * 0.82)
            visible: opacity > 0.01
            z: 2
            transform: Translate { id: currentDrift }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: currentPointer.containsMouse ? Theme.accent : Theme.moon
                opacity: telemetryLayer.shaderReady ? 1 - root.telemetryFluid : 1
            }
            Column {
                anchors.centerIn: parent; spacing: 0; opacity: root.telemetryTextOpacity
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentSky.primary ? currentSky.primary.icon
                        : Weather.available ? (Weather.current.icon || "·") : "·"
                    color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentSky.primary ? root.temperature(currentSky.primary.max)
                        : Weather.available ? root.temperature(Weather.current.temp) : "--"
                    color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 17; font.weight: Font.Black
                }
            }
            MouseArea {
                id: currentPointer
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                enabled: root.telemetryMerge < 0.01
                onClicked: Weather.refresh()
            }
            SequentialAnimation {
                loops: Animation.Infinite
                running: Settings.motion && currentSky.visible && root.sideThree > 0.99 && root.telemetryMerge < 0.01
                ParallelAnimation {
                    NumberAnimation { target: currentDrift; property: "x"; to: 4; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { target: currentDrift; property: "y"; to: 4; duration: 1800; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: currentDrift; property: "x"; to: -5; duration: 2400; easing.type: Easing.InOutSine }
                    NumberAnimation { target: currentDrift; property: "y"; to: -2; duration: 2400; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: currentDrift; property: "x"; to: 0; duration: 1700; easing.type: Easing.InOutSine }
                    NumberAnimation { target: currentDrift; property: "y"; to: 0; duration: 1700; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Productivity.CalendarModeControls {
        calendar: root
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 28
        z: 20
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Settings.motion ? 420 : 0; easing.type: Easing.InOutCubic }
        }
    }

    Timer {
        interval: Settings.motion && root.calendarMode === 0 ? 16 : 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.smoothEpoch = Date.now()
    }
    Component.onCompleted: { forceActiveFocus(); moonFace.requestPaint(); }
}
