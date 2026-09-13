import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

pragma ComponentBehavior: Bound

Item {
    id: root

    property string query: ""
    property string currentFilter: "All"
    property int orbitOffset: 0
    property bool searchOpen: false
    property bool optionsOpen: false
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 16
        width: 310; height: 40; radius: 12; z: 100
        visible: Environment.libraryLoading || Environment.libraryError.length > 0
        color: Theme.mantle
        Text {
            anchors.centerIn: parent; color: Theme.moon
            text: Environment.libraryLoading ? "Loading library…" : "Library couldn’t load · Retry"
        }
        MouseArea {
            anchors.fill: parent
            enabled: !Environment.libraryLoading
            cursorShape: Qt.PointingHandCursor
            onClicked: Environment.refreshWallpapers()
        }
    }
    // A freshly constructed orbit is complete by default. The host calls
    // beginDeployment only after its own surface reveal has actually landed.
    property real entrance: 1
    property real deployProgress: 1
    property real orbitPhase: 0

    readonly property var filters: [
        { "label": "EVERYTHING", "value": "All", "glyph": "✦", "tone": Theme.accent },
        { "label": "TONANTZINTLA", "value": "Tonantzintla", "glyph": "A", "tone": Theme.cyan },
        { "label": "ONLINE", "value": "Online", "glyph": "◎", "tone": Theme.success },
        { "label": "VIDEO", "value": "Video", "glyph": "▶", "tone": Theme.rose }
    ]
    readonly property bool hasOnlineWorlds: Environment.wallpapers.some(function(entry) { return entry.source === "Online"; })
    readonly property bool hasVideoWorlds: Environment.wallpapers.some(function(entry) { return entry.kind === "video"; })
    readonly property var filteredWallpapers: Environment.wallpapers.filter(function(entry) {
        const needle = root.query.trim().toLowerCase();
        const textMatch = !needle || (entry.name + " " + entry.source).toLowerCase().indexOf(needle) >= 0;
        if (!textMatch && root.currentFilter !== "Online") return false;
        if (root.currentFilter === "All") return textMatch;
        if (root.currentFilter === "Video") return !root.hasVideoWorlds ? textMatch : entry.kind === "video" && textMatch;
        if (root.currentFilter === "Online") return !root.hasOnlineWorlds ? textMatch : entry.source === "Online";
        return entry.source === root.currentFilter && textMatch;
    })
    readonly property var selectedEntry: filteredWallpapers.length > 0
        ? filteredWallpapers[((orbitOffset % filteredWallpapers.length) + filteredWallpapers.length) % filteredWallpapers.length]
        : null

    function previewUrl(entry) {
        if (!entry || !entry.preview) return "";
        return entry.preview.indexOf("://") >= 0 ? entry.preview : "file://" + entry.preview;
    }

    function orbitEntry(slot) {
        if (!filteredWallpapers.length) return null;
        const index = ((orbitOffset + slot) % filteredWallpapers.length + filteredWallpapers.length)
            % filteredWallpapers.length;
        return filteredWallpapers[index];
    }

    function rotateTo(slot) { orbitOffset += slot; }
    function shuffleOrbit() {
        if (filteredWallpapers.length > 1)
            orbitOffset = Math.floor(Math.random() * filteredWallpapers.length);
    }
    function runSearch() {
        if (!query.trim().length) return;
        activateFilter("Online");
        Environment.searchOnline(query);
        searchInput.focus = false;
    }
    function focusPrimary() {
        searchOpen = true;
        Qt.callLater(function() {
            searchInput.forceActiveFocus();
            searchInput.cursorPosition = searchInput.text.length;
        });
    }

    function activateFilter(value) {
        // Reset before swapping the model so newly-created delegates enter the
        // same deployment instead of briefly appearing at their final orbit.
        beginDeployment();
        currentFilter = value;
        orbitOffset = 0;
        if (value === "Online" && !hasOnlineWorlds)
            focusPrimary();
    }

    function beginDeployment() {
        entranceAnimation.stop();
        deploymentAnimation.stop();
        entrance = 0;
        deployProgress = 0;
        entranceDelay.restart();
    }

    // Data and query changes update delegates in place. Only the host reveal
    // and explicit filter controls are allowed to relaunch choreography.

    Timer {
        id: entranceDelay
        interval: 24
        onTriggered: {
            entranceAnimation.restart();
            deploymentAnimation.restart();
        }
    }

    NumberAnimation {
        id: entranceAnimation
        target: root
        property: "entrance"
        from: 0
        to: 1
        duration: Settings.motion ? 430 : 0
        easing.type: Easing.OutBack
    }

    NumberAnimation {
        id: deploymentAnimation
        target: root
        property: "deployProgress"
        from: 0
        to: 1
        duration: Settings.motion ? 980 : 0
        easing.type: Easing.OutCubic
    }

    NumberAnimation on orbitPhase {
        from: 0
        to: Math.PI * 2
        duration: 28000
        loops: Animation.Infinite
        running: root.visible
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 1
        scale: 0.88 + root.entrance * 0.12

        Item {
            id: outerOrbit
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            width: Math.min(parent.width - 250, 1210)
            height: Math.min(parent.height - 110, 430)
        }

        Repeater {
            model: Math.min(7, root.filteredWallpapers.length)

            Item {
                id: satellite
                required property int index
                readonly property var entry: root.orbitEntry(index + 1)
                readonly property real angle: -Math.PI / 2
                    + index * (Math.PI * 2 / Math.max(1, Math.min(7, root.filteredWallpapers.length)))
                    + root.orbitPhase
                    + Math.sin(root.orbitPhase * 3 + index) * 0.025
                readonly property real depth: (Math.sin(angle) + 1) / 2
                readonly property real deploymentDelay: index * 0.065
                readonly property real deployment: Math.max(0, Math.min(1,
                    (root.deployProgress - deploymentDelay) / Math.max(0.01, 1 - deploymentDelay)))

                width: 96 + depth * 48
                height: width
                x: stage.width / 2 + Math.cos(angle) * outerOrbit.width * 0.48 * deployment - width / 2
                y: stage.height / 2 + 14 + Math.sin(angle) * outerOrbit.height * 0.48 * deployment - height / 2
                // Deployment controls position and scale, never translucency.
                // A satellite appears solid as soon as its stagger begins.
                visible: deployment > 0.001
                opacity: 1
                scale: (0.35 + deployment * 0.65) * (0.84 + depth * 0.18)
                    * (satellitePointer.containsMouse ? 1.1 : 1)
                z: satellitePointer.containsMouse ? 20 : Math.round(depth * 10)

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.mantle
                    border.width: 0
                    CircularArtwork { anchors.fill: parent; source: root.previewUrl(satellite.entry) }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 7
                    width: satelliteName.implicitWidth + 18
                    height: 26
                    radius: 13
                    color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.94)
                    opacity: satellitePointer.containsMouse ? 1 : 0
                    scale: satellitePointer.containsMouse ? 1 : 0.82
                    Text {
                        id: satelliteName
                        anchors.centerIn: parent
                        text: satellite.entry ? satellite.entry.name : ""
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    Behavior on opacity { NumberAnimation { duration: 105 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: satellitePointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.rotateTo(satellite.index + 1)
                    onDoubleClicked: if (satellite.entry) Environment.setWallpaper(satellite.entry)
                }
            }
        }

        Item {
            id: worldCore
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            width: 268
            height: 268
            z: 5
            scale: corePointer.containsMouse ? 1.035 : 1

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.mantle
                border.width: 0
                CircularArtwork { anchors.fill: parent; anchors.margins: 5; source: root.previewUrl(root.selectedEntry) }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.04) }
                        GradientStop { position: 0.58; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.12) }
                        GradientStop { position: 1; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.86) }
                    }
                }
                Column {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.leftMargin: 30; anchors.rightMargin: 30; anchors.bottomMargin: 28
                    spacing: 3
                    Text {
                        width: parent.width
                        text: root.selectedEntry ? root.selectedEntry.name : "NO WORLD FOUND"
                        color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 15; font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: Environment.wallpaperBusy ? "APPLYING…" : "CLICK TO APPLY"
                        color: Environment.wallpaperBusy ? Theme.warning : Theme.accent
                        font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            MouseArea {
                id: corePointer
                anchors.fill: parent
                enabled: root.selectedEntry && Environment.canSetWallpaper && !Environment.wallpaperBusy
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                onClicked: Environment.setWallpaper(root.selectedEntry)
            }
            Behavior on scale { NumberAnimation { duration: Settings.motion ? 160 : 0; easing.type: Easing.OutBack } }
        }

        Rectangle {
            anchors.horizontalCenter: worldCore.horizontalCenter
            anchors.top: worldCore.bottom
            anchors.topMargin: -17
            width: 58; height: 58; radius: 29; z: 10
            color: shufflePointer.containsMouse ? Theme.cyan : Theme.accent
            border.width: 0
            Text { anchors.centerIn: parent; text: "↻"; color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 24; font.weight: Font.Bold }
            MouseArea { id: shufflePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shuffleOrbit() }
            ToolTipBubble { text: "SHUFFLE"; shown: shufflePointer.containsMouse }
        }

        Column {
            anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
            spacing: 10; z: 12

            Rectangle {
                width: root.searchOpen ? 390 : 52; height: 52; radius: 26
                color: searchInput.activeFocus ? Theme.elevated : Theme.mantle
                border.width: 0
                clip: true
                Text { anchors.left: parent.left; anchors.leftMargin: 17; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: Theme.accent; font.family: Theme.fontDisplay; font.pixelSize: 19; font.weight: Font.Bold }
                TextInput {
                    id: searchInput
                    visible: root.searchOpen
                    anchors.left: parent.left; anchors.leftMargin: 50; anchors.right: parent.right; anchors.rightMargin: 48; anchors.verticalCenter: parent.verticalCenter
                    text: root.query; color: Theme.moon; selectionColor: Theme.accent; selectedTextColor: Theme.void_
                    font.family: Theme.fontText; font.pixelSize: 12; clip: true
                    onTextChanged: root.query = text
                    Keys.onReturnPressed: root.runSearch()
                }
                Text { visible: root.searchOpen && !searchInput.text.length; anchors.left: searchInput.left; anchors.verticalCenter: parent.verticalCenter; text: "search wallpapers…"; color: Theme.lineBright; font.family: Theme.fontText; font.pixelSize: 12 }
                Text { visible: root.searchOpen; anchors.right: parent.right; anchors.rightMargin: 17; anchors.verticalCenter: parent.verticalCenter; text: Environment.onlineBusy ? "⌁" : "↵"; color: Theme.cyan; font.family: Theme.fontMono; font.pixelSize: 14 }
                MouseArea {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 50
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.searchOpen = !root.searchOpen;
                        if (root.searchOpen) Qt.callLater(function() { searchInput.forceActiveFocus(); });
                    }
                }
                Behavior on width { NumberAnimation { duration: Settings.motion ? 240 : 0; easing.type: Easing.OutBack } }
            }

            Repeater {
                model: root.filters
                Rectangle {
                    id: filterSatellite
                    required property var modelData
                    readonly property bool active: root.currentFilter === modelData.value
                    width: 52; height: 52; radius: 26
                    color: active ? modelData.tone : filterPointer.containsMouse ? Theme.elevated : Theme.mantle
                    border.width: 0
                    Text { anchors.centerIn: parent; text: filterSatellite.modelData.glyph; color: filterSatellite.active ? Theme.void_ : Theme.muted; font.family: Theme.fontDisplay; font.pixelSize: 18; font.weight: Font.Bold }
                    MouseArea { id: filterPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activateFilter(filterSatellite.modelData.value) }
                    ToolTipBubble { text: filterSatellite.modelData.label; shown: filterPointer.containsMouse }
                }
            }

            Rectangle {
                width: 148; height: 44; radius: 22
                color: libraryPointer.containsMouse ? Theme.accent : Theme.mantle
                border.width: 0
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "▧"
                        color: libraryPointer.containsMouse ? Theme.void_ : Theme.accent
                        font.family: Theme.fontDisplay
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "LIBRARY"
                        color: libraryPointer.containsMouse ? Theme.void_ : Theme.moon
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }
                MouseArea {
                    id: libraryPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Environment.openWallpaperLibrary()
                }
                ToolTipBubble {
                    text: "OPEN WALLPAPER LIBRARY"
                    shown: libraryPointer.containsMouse
                }
            }
        }

        Column {
            anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
            spacing: 10; z: 12
            Rectangle {
                width: 52; height: 52; radius: 26
                color: root.optionsOpen ? Theme.accent : optionsPointer.containsMouse ? Theme.elevated : Theme.mantle
                border.width: 0
                Text { anchors.centerIn: parent; text: "⋯"; color: root.optionsOpen ? Theme.void_ : Theme.accent; font.family: Theme.fontDisplay; font.pixelSize: 24; font.weight: Font.Bold }
                MouseArea { id: optionsPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.optionsOpen = !root.optionsOpen }
                ToolTipBubble { text: "OPTIONS"; shown: optionsPointer.containsMouse && !root.optionsOpen; anchors.left: undefined; anchors.right: parent.left; anchors.rightMargin: 8 }
            }
            Rectangle {
                width: 52; height: 52; radius: 26
                color: Settings.adaptivePalette ? Theme.rose : palettePointer.containsMouse ? Theme.elevated : Theme.mantle
                border.width: 0
                Row { anchors.centerIn: parent; spacing: -2
                    Repeater { model: [Theme.accent, Theme.cyan, Theme.rose]
                        Rectangle { required property var modelData; width: 10; height: 18; radius: 5; color: modelData }
                    }
                }
                MouseArea { id: palettePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.adaptivePalette = !Settings.adaptivePalette }
                ToolTipBubble { text: Settings.adaptivePalette ? "MATUGEN ONLINE" : "MATUGEN OFFLINE"; shown: palettePointer.containsMouse; anchors.left: undefined; anchors.right: parent.left; anchors.rightMargin: 8 }
            }
        }

        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 84; anchors.verticalCenter: parent.verticalCenter
            width: root.optionsOpen ? 260 : 0; height: 310; radius: 130
            color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.97)
            border.width: 0
            opacity: root.optionsOpen ? 1 : 0; clip: true; z: 11
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32; spacing: 12
                Text { text: "OPTIONS"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 14; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                Text { text: "OUTPUT"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        model: ["ALL"].concat(Environment.outputNames)
                        Rectangle {
                            id: outputDot
                            required property string modelData
                            required property int index
                            readonly property bool active: modelData === "ALL" ? Settings.wallpaperOutputs === "all" : Environment.outputsSelected(modelData)
                            width: 38; height: 38; radius: 19; color: active ? Theme.accent : Theme.elevated
                            Text { anchors.centerIn: parent; text: outputDot.modelData === "ALL" ? "∞" : (outputDot.index + 1); color: outputDot.active ? Theme.void_ : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: outputDot.modelData === "ALL" ? Environment.selectAllOutputs() : Environment.toggleOutput(outputDot.modelData) }
                        }
                    }
                }
                Text { text: "TRANSITION"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        model: ["any", "fade", "grow", "wave"]
                        Rectangle {
                            id: transitionDot
                            required property string modelData
                            readonly property bool active: Settings.wallpaperTransition === modelData
                            width: 38; height: 38; radius: 19; color: active ? Theme.cyan : Theme.elevated
                            Text { anchors.centerIn: parent; text: transitionDot.modelData.charAt(0).toUpperCase(); color: transitionDot.active ? Theme.void_ : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.wallpaperTransition = transitionDot.modelData }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { text: Environment.wallpaperStatus; color: Environment.canSetWallpaper ? Theme.success : Theme.warning; font.family: Theme.fontText; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
            }
            Behavior on width { NumberAnimation { duration: Settings.motion ? 230 : 0; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: Settings.motion ? 120 : 0 } }
        }
    }

    component ToolTipBubble: Rectangle {
        property string text: ""
        property bool shown: false
        anchors.left: parent.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: label.implicitWidth + 18; height: 27; radius: 13
        color: Theme.mantle; border.width: 0
        opacity: shown ? 1 : 0; scale: shown ? 1 : 0.82; z: 30
        Text { id: label; anchors.centerIn: parent; text: parent.text; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.DemiBold }
        Behavior on opacity { NumberAnimation { duration: 90 } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
    }

    component CircularArtwork: Canvas {
        id: artworkCanvas
        property string source: ""
        property string loadedSource: ""

        renderTarget: Canvas.Image
        antialiasing: true

        function syncImage() {
            if (loadedSource.length > 0 && loadedSource !== source)
                unloadImage(loadedSource);
            loadedSource = source;
            if (source.length > 0)
                loadImage(source);
            requestPaint();
        }

        onSourceChanged: syncImage()
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: syncImage()

        Image {
            id: sizeProbe
            source: artworkCanvas.source
            visible: false
            asynchronous: true
            onStatusChanged: artworkCanvas.requestPaint()
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!source.length || !isImageLoaded(source))
                return;

            const size = sizeProbe.sourceSize;
            if (!size.width || !size.height)
                return;
            const scale = Math.max(width / size.width, height / size.height);
            const drawWidth = size.width * scale;
            const drawHeight = size.height * scale;
            const drawX = (width - drawWidth) / 2;
            const drawY = (height - drawHeight) / 2;

            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2, false);
            ctx.closePath();
            ctx.clip();
            ctx.drawImage(source, drawX, drawY, drawWidth, drawHeight);
            ctx.restore();
        }
    }
}
