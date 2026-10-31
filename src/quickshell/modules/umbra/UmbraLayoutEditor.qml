pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "UmbraLayout.js" as LayoutModel
import "../../components/identity/LockStyles.js" as LockStyles

Item {
    id: root
    implicitHeight: content.implicitHeight
    property var draft: currentLayout()
    property var undoStack: []
    property var redoStack: []
    property string selected: "clock"
    property bool playVideo: false
    property bool changingLayout: false
    property bool gridEnabled: false
    property real guideX: -1
    property real guideY: -1
    function clearGuides() { guideX = -1; guideY = -1; }
    function rotateSelected() { commit(LayoutModel.rotate(draft,selected,miniature.width,miniature.height)); }
    function finishGesture() { commit(draft); clearGuides(); }
    function cancelGesture() { draft = currentLayout(); clearGuides(); }
    function currentLayout() {
        const value = LayoutModel.normalize(Settings.umbraLayout);
        value.media.visible = value.media.visible && Settings.umbraShowMedia;
        value.weather.visible = value.weather.visible && Settings.umbraShowWeather;
        return value;
    }
    function setLayout(value) {
        changingLayout = true;
        Settings.umbraLayout = value;
        Settings.umbraShowMedia = value.media.visible;
        Settings.umbraShowWeather = value.weather.visible;
        changingLayout = false;
        draft = currentLayout();
    }
    property string pickingMode: "image"
    function commit(next) {
        const normalized = LayoutModel.normalize(next);
        if (JSON.stringify(normalized) === JSON.stringify(currentLayout())) return;
        undoStack = LayoutModel.push(undoStack, currentLayout());
        redoStack = [];
        setLayout(normalized);
        draft = normalized;
    }
    function edit(patch) { commit(LayoutModel.update(draft, selected, patch)); }
    function undo() {
        if (!undoStack.length) return;
        redoStack = LayoutModel.push(redoStack, currentLayout());
        const stack = undoStack.slice();
        setLayout(stack.pop()); undoStack = stack;
        draft = currentLayout();
    }
    function redo() {
        if (!redoStack.length) return;
        undoStack = LayoutModel.push(undoStack, currentLayout());
        const stack = redoStack.slice();
        setLayout(stack.pop()); redoStack = stack;
        draft = currentLayout();
    }
    function move(dx, dy, resize) {
        const rect = draft[selected];
        edit(resize ? {w: rect.w+dx, h: rect.h+dy} : {x: rect.x+dx, y: rect.y+dy});
    }
    Component.onCompleted: { Umbra.inspectBackground(true); if (Settings.umbraFingerprintService.length) Umbra.inspectFingerprint(); }
    Connections {
        target: Settings
        function onUmbraLayoutChanged() {
            root.draft = root.currentLayout();
            if (!root.changingLayout) { root.undoStack = []; root.redoStack = []; }
        }
        function onUmbraShowMediaChanged() { if (!root.changingLayout) { root.draft = root.currentLayout(); root.undoStack = []; root.redoStack = []; } }
        function onUmbraShowWeatherChanged() { if (!root.changingLayout) { root.draft = root.currentLayout(); root.undoStack = []; root.redoStack = []; } }
        function onUmbraBackgroundPathChanged() { root.playVideo = false; }
        function onUmbraBackgroundModeChanged() { root.playVideo = false; }
    }
    FileDialog {
        id: filePicker
        title: root.pickingMode === "video" ? "Choose a lock video · up to 720p / 30 fps" : "Choose a lock image"
        fileMode: FileDialog.OpenFile
        nameFilters: root.pickingMode === "video" ? ["Video files (*.mp4 *.webm *.mkv *.mov)"] : ["Image files (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: {
            Settings.umbraBackgroundMode = root.pickingMode;
            Settings.umbraBackgroundPath = selectedFile.toString();
            Umbra.inspectBackground();
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    ColumnLayout {
        id: content
        width: parent.width; spacing: Theme.spaceMd
        Text { text: "Umbra layout"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 20 }
        Text {
            Layout.fillWidth: true
            text: "Arrange the lock screen widgets. Password entry and the black hole stay in fixed positions. This preview does not lock your screen or check your password."
            wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Background"
            value: Settings.umbraBackgroundMode
            choices: [{label:"Desktop image",value:"inherit"},{label:"Custom image",value:"image"},{label:"Custom video",value:"video"},{label:"Solid",value:"solid"}]
            onSelected: function(value) { Settings.umbraBackgroundMode = value; }
        }
        RowLayout {
            Layout.fillWidth: true
            ActionButton { text: "Choose image…"; onClicked: { root.pickingMode = "image"; filePicker.open(); } }
            ActionButton { text: "Choose video…"; onClicked: { root.pickingMode = "video"; filePicker.open(); } }
            ActionButton {
                visible: Settings.umbraBackgroundMode === "video"
                text: root.playVideo ? "Stop video preview" : "Play video preview"
                enabled: Settings.umbraBackgroundPath.length > 0
                onClicked: {
                    if (!root.playVideo) Umbra.inspectBackground(true);
                    root.playVideo = !root.playVideo;
                }
            }
        }
        SettingTextField {
            Layout.fillWidth: true
            visible: Settings.umbraBackgroundMode === "image" || Settings.umbraBackgroundMode === "video"
            label: "Local background file"; value: Settings.umbraBackgroundPath
            onCommitted: function(value) { Settings.umbraBackgroundPath = value; }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: miniatureBackground.statusText.length > 0 ? miniatureBackground.statusText
                : "The desktop wallpaper is unchanged. Missing media falls back to the bundled still image."
            color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
        Text {
            Layout.fillWidth: true; visible: Settings.umbraBackgroundMode === "video"
            text: "Video repeats its first 8 seconds without sound, up to 640 × 360 at 12 fps. Only the active screen plays video; other screens show a still image to limit memory use."
            wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Clock face"
            value: Settings.umbraClockVariant
            choices: [{label:"Original",value:"classic"},{label:"Compact",value:"compact"},{label:"Orbital",value:"orbital"},{label:"Luminous",value:"luminous"},{label:"Typographic",value:"typographic"}]
            onSelected: function(value) { Settings.umbraClockVariant = value; }
        }
        Rectangle {
            id: miniature
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(180, width * 9 / 16)
            color: Theme.void_; radius: 12; clip: true
            UmbraBackground {
                id: miniatureBackground
                anchors.fill: parent
                active: true
                videoEnabled: root.playVideo
                preview: true
            }
            ThemeMark {
                x: parent.width * .50; y: parent.height * .15
                width: parent.width * .42; height: width * .7
                }
            Text {
                x: parent.width*.045; y: parent.height*.60
                text: "Password entry · fixed"; color: Theme.muted
                font.family: Theme.fontMono; font.pixelSize: 9
            }
            Repeater {
                model: root.gridEnabled ? Math.floor(miniature.width/20) : 0
                Rectangle { required property int index; x: (index+1)*20; width: 1; height: miniature.height; color: Theme.line; opacity: .35 }
            }
            Repeater {
                model: root.gridEnabled ? Math.floor(miniature.height/20) : 0
                Rectangle { required property int index; y: (index+1)*20; height: 1; width: miniature.width; color: Theme.line; opacity: .35 }
            }
            Repeater {
                model: LayoutModel.keys
                Rectangle {
                    id: tile
                    required property string modelData
                    readonly property var rect: root.draft[modelData]
                    x: rect.x * miniature.width; y: rect.y * miniature.height
                    width: rect.w * miniature.width; height: rect.h * miniature.height
                    color: root.selected === modelData ? Theme.accentVeil : Theme.controlRest
                    border.color: root.selected === modelData ? Theme.focusRing : Theme.line
                    border.width: 1; radius: 4
                    opacity: rect.visible ? 1 : .35
                    objectName: "layoutTile_" + modelData
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Position " + modelData
                    Keys.onPressed: function(event) {
                        root.selected = modelData;
                        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { root.edit({visible:false}); event.accepted=true; return; }
                        if (event.key === Qt.Key_R) { root.rotateSelected(); event.accepted=true; return; }
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                            if (event.modifiers & Qt.ShiftModifier) root.redo(); else root.undo();
                            event.accepted=true; return;
                        }
                        const amount = event.modifiers & Qt.ControlModifier ? .005 : .02;
                        const resize = Boolean(event.modifiers & Qt.ShiftModifier);
                        if (event.key === Qt.Key_Left) root.move(-amount,0,resize);
                        else if (event.key === Qt.Key_Right) root.move(amount,0,resize);
                        else if (event.key === Qt.Key_Up) root.move(0,-amount,resize);
                        else if (event.key === Qt.Key_Down) root.move(0,amount,resize);
                        else return;
                        event.accepted = true;
                    }
                    UmbraPlacement {
                        anchors.fill: parent; anchors.margins: 3
                        placementRotation: tile.rect.rotation
                        placementOpacity: tile.rect.opacity
                        InstrumentClock {
                            anchors.fill: parent
                            visible: tile.modelData === "clock" && Settings.umbraClockVariant !== "classic"
                            active: visible && tile.rect.visible
                            dateTime: clock.date
                            variant: Settings.umbraClockVariant === "classic" ? "typographic" : Settings.umbraClockVariant
                        }
                        UmbraClassicClock {
                            anchors.fill: parent
                            visible: tile.modelData === "clock" && Settings.umbraClockVariant === "classic"
                            dateTime: clock.date
                            // The miniature uses the selected identity's lock typography.
                            timeType: LockStyles.style(Theme.identity.id).clock
                            dateType: LockStyles.style(Theme.identity.id).date
                        }
                        Loader {
                            anchors.fill: parent
                            active: tile.modelData === "media"
                            sourceComponent: UmbraMediaInstrument { active: visible && tile.rect.visible; interactive: false }
                        }
                        Loader {
                            anchors.fill: parent
                            active: ["weather","battery","keyboard"].indexOf(tile.modelData) >= 0
                            sourceComponent: UmbraStatusInstrument { kind: tile.modelData; textSize: 9 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                        property point origin
                        property point initial
                        onPressed: function(mouse) {
                            root.selected = tile.modelData; tile.forceActiveFocus();
                            origin = mapToItem(miniature, mouse.x, mouse.y);
                            initial = Qt.point(tile.rect.x, tile.rect.y);
                        }
                        onPositionChanged: function(mouse) {
                            if (!pressed) return;
                            const p = mapToItem(miniature,mouse.x,mouse.y);
                            const result = LayoutModel.snap(root.draft,tile.modelData,initial.x+(p.x-origin.x)/miniature.width,
                                initial.y+(p.y-origin.y)/miniature.height,miniature.width,miniature.height,root.gridEnabled);
                            root.draft = LayoutModel.update(root.draft,tile.modelData,result.rect);
                            root.guideX=result.guideX; root.guideY=result.guideY;
                        }
                        onReleased: root.finishGesture()
                        onCanceled: root.cancelGesture()
                    }
                    Repeater {
                        model: ["top-left","top","top-right","right","bottom-right","bottom","bottom-left","left"]
                        Rectangle {
                            id: handle
                            required property string modelData
                            objectName: "resize_" + tile.modelData + "_" + modelData
                            visible: root.selected === tile.modelData
                            x: modelData.indexOf("left")>=0 ? 0 : modelData.indexOf("right")>=0 ? tile.width-width : (tile.width-width)/2
                            y: modelData.indexOf("top")>=0 ? 0 : modelData.indexOf("bottom")>=0 ? tile.height-height : (tile.height-height)/2
                            width: 10; height: 10; radius: 2; color: Theme.accent
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: handle.modelData === "left" || handle.modelData === "right" ? Qt.SizeHorCursor
                                    : handle.modelData === "top" || handle.modelData === "bottom" ? Qt.SizeVerCursor
                                    : handle.modelData === "top-left" || handle.modelData === "bottom-right" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                property point origin
                                property var initial
                                onPressed: function(mouse) {
                                    root.selected = tile.modelData;
                                    origin = mapToItem(miniature,mouse.x,mouse.y);
                                    initial = Object.assign({},tile.rect);
                                }
                                onPositionChanged: function(mouse) {
                                    if (!pressed) return;
                                    const p=mapToItem(miniature,mouse.x,mouse.y);
                                    root.draft=LayoutModel.update(root.draft,tile.modelData,LayoutModel.resize(initial,handle.modelData,
                                        (p.x-origin.x)/miniature.width,(p.y-origin.y)/miniature.height,miniature.width,miniature.height,root.gridEnabled));
                                }
                                onReleased: root.finishGesture()
                                onCanceled: root.cancelGesture()
                            }
                        }
                    }
                }
            }
            Rectangle { visible: root.guideX >= 0; x: root.guideX*miniature.width; width: 1; height: parent.height; color: Theme.cyan }
            Rectangle { visible: root.guideY >= 0; y: root.guideY*miniature.height; height: 1; width: parent.width; color: Theme.cyan }
        }
        SettingToggle { Layout.fillWidth: true; label: "20 px grid and snapping"; checked: root.gridEnabled; onToggled: root.gridEnabled = !root.gridEnabled }
        Text { Layout.fillWidth: true; text: "Drag to move; use any edge or corner to resize. Arrows move, Shift+arrows resize, Ctrl takes smaller steps. R rotates; Delete hides. Ctrl+Z / Ctrl+Shift+Z undo / redo."; wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
        SettingChoice {
            Layout.fillWidth: true; label: "Selected widget"; value: root.selected
            choices: LayoutModel.keys.map(function(key) { return {label:key,value:key}; })
            onSelected: function(value) { root.selected=value; }
        }
        SettingToggle {
            Layout.fillWidth: true; label: "Show " + root.selected
            checked: root.draft[root.selected].visible
            onToggled: root.edit({visible: !root.draft[root.selected].visible})
        }
        DockSettingSlider {
            Layout.fillWidth: true; label: "Widget opacity"; suffix: "%"
            from: 0; to: 100; stepSize: 1; value: Math.round(root.draft[root.selected].opacity*100)
            onEdited: function(value) { root.edit({opacity:value/100}); }
        }
        Text {
            Layout.fillWidth: true
            readonly property var rect: root.draft[root.selected]
            text: Math.round(rect.w*miniature.width) + " × " + Math.round(rect.h*miniature.height)
                + " px in miniature · aspect " + (rect.w*miniature.width/(rect.h*miniature.height)).toFixed(2)
                + " · rotation " + rect.rotation + "°"
            color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11
        }
        RowLayout {
            ActionButton { text: "Rotate 90°"; onClicked: root.rotateSelected() }
            ActionButton { text: "Hide widget"; enabled: root.draft[root.selected].visible; onClicked: root.edit({visible:false}) }
        }
        RowLayout {
            ActionButton { text: "Undo layout"; enabled: root.undoStack.length > 0; onClicked: root.undo() }
            ActionButton { text: "Redo layout"; enabled: root.redoStack.length > 0; onClicked: root.redo() }
            ActionButton { text: "Reset layout"; onClicked: root.commit({}) }
        }
        Text { text: "Fingerprint authentication"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 16 }
        SettingChoice {
            Layout.fillWidth: true; visible: Umbra.fingerprintAvailable
            label: "Fingerprint appearance"; value: Settings.umbraFingerprintLook
            choices: [{label:"Original",value:"original"},{label:"Ridges",value:"ridges"},{label:"Orbital",value:"orbital"}]
            onSelected: function(value) { Settings.umbraFingerprintLook=value; }
        }
        SettingToggle {
            Layout.fillWidth: true; visible: Umbra.fingerprintAvailable
            label: "Show fingerprint text"; checked: Settings.umbraFingerprintShowText
            onToggled: Settings.umbraFingerprintShowText=!Settings.umbraFingerprintShowText
        }
        UmbraFingerprintVisual {
            visible: Umbra.fingerprintAvailable && (Settings.umbraFingerprintLook !== "original" || !Settings.umbraFingerprintShowText)
            interactive: false
        }
        SettingTextField {
            Layout.fillWidth: true; label: "Existing fingerprint PAM profile"
            value: Settings.umbraFingerprintService
            detail: "Optional. No system configuration is created or changed. Password remains available."
            onCommitted: function(value) { Settings.umbraFingerprintService=value; Umbra.inspectFingerprint(); }
        }
        RowLayout {
            ActionButton { text: "Check reader support"; enabled: Settings.umbraFingerprintService.length > 0; onClicked: Umbra.inspectFingerprint() }
            Text { Layout.fillWidth: true; text: Umbra.fingerprintStatus; wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
        }
    }
}
