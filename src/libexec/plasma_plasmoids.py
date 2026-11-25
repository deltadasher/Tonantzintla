"""Native KDE Plasma 6 Plasmoid generators for Tonantzintla (GLSL ShaderEffect + Spring Physics)."""
from __future__ import annotations

import json
from pathlib import Path

PLASMOID_IDS = (
    "org.tonantzintla.launcher",
    "org.tonantzintla.workspaces",
    "org.tonantzintla.media",
    "org.tonantzintla.clock",
    "org.tonantzintla.status",
)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _write_json(path: Path, payload: dict) -> None:
    _write_text(path, json.dumps(payload, indent=4) + "\n")


LAUNCHER_QML = r"""pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    switchWidth: 420
    switchHeight: 360

    property date now: new Date()
    property string searchText: ""
    property int selectedCategory: 0
    property int selectedAppIndex: -1
    property int orbitPage: 0
    property bool orbitalMode: true
    property real cursorNormX: 0.0
    property real cursorNormY: 0.0
    property real orbitPhase: 0.0
    property real typingEnergy: 0.0
    property real orbitBloom: 1.0
    property bool mathCopied: false
    property var categories: []

    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    function contrastFor(col) {
        return (0.2126 * linChannel(col.r) + 0.7152 * linChannel(col.g) + 0.0722 * linChannel(col.b)) > 0.34 ? "#101016" : "#f8f7fc";
    }
    readonly property color accentFg: contrastFor(accentColor)
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family

    readonly property real lunarCycle: {
        const refMs = Date.UTC(2000, 0, 6, 18, 14, 0);
        const days = (now.getTime() - refMs) / 86400000.0;
        const synodic = 29.53058867;
        let phase = (days % synodic) / synodic;
        if (phase < 0) phase += 1.0;
        return phase;
    }
    // The disc only changes visibly every few hours; repaint on that step, not every second.
    readonly property int moonStep: Math.round(lunarCycle * 240)

    // Safe arithmetic-only evaluator (no eval/Function)
    function evalSafeMath(expr) {
        const trimmed = (expr || "").trim();
        if (trimmed.length < 3 || trimmed.length > 64) return "";
        if (!/^[0-9+\-*/().\s%^]+$/.test(trimmed)) return "";
        if (!/[+\-*/%^]/.test(trimmed)) return "";
        try {
            const tokens = trimmed.match(/\d+(?:\.\d+)?|[+\-*/()%^]/g);
            if (!tokens || tokens.length === 0) return "";
            let pos = 0;
            function peek() { return pos < tokens.length ? tokens[pos] : ""; }
            function take() { return tokens[pos++]; }
            function parseExpr() {
                let left = parseTerm();
                while (peek() === "+" || peek() === "-") {
                    const op = take();
                    const right = parseTerm();
                    left = op === "+" ? left + right : left - right;
                }
                return left;
            }
            function parseTerm() {
                let left = parsePow();
                while (peek() === "*" || peek() === "/" || peek() === "%") {
                    const op = take();
                    const right = parsePow();
                    if ((op === "/" || op === "%") && right === 0) return NaN;
                    left = op === "*" ? left * right : (op === "/" ? left / right : left % right);
                }
                return left;
            }
            function parsePow() {
                let base = parseUnary();
                if (peek() === "^") {
                    take();
                    base = Math.pow(base, parsePow());
                }
                return base;
            }
            function parseUnary() {
                if (peek() === "-") { take(); return -parsePow(); }
                if (peek() === "+") { take(); return parseUnary(); }
                if (peek() === "(") {
                    take();
                    const val = parseExpr();
                    if (take() !== ")") return NaN;
                    return val;
                }
                const tok = take();
                return tok === undefined ? NaN : Number(tok);
            }
            const value = parseExpr();
            if (pos !== tokens.length || !isFinite(value)) return "";
            return String(Math.round(value * 1000000) / 1000000);
        } catch (e) {
            return "";
        }
    }
    readonly property string mathResult: evalSafeMath(searchText)

    TextEdit {
        id: clipHelper
        visible: false
    }

    Timer {
        id: copiedResetTimer
        interval: 1200
        repeat: false
        onTriggered: root.mathCopied = false
    }

    NumberAnimation {
        id: bloomAnim
        target: root
        property: "orbitBloom"
        from: 0.0
        to: 1.0
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 0.85
    }

    function triggerOrbitBloom() {
        bloomAnim.restart();
    }

    function copyMathResult() {
        if (!mathResult) return;
        clipHelper.text = mathResult;
        clipHelper.selectAll();
        clipHelper.copy();
        mathCopied = true;
        copiedResetTimer.restart();
    }

    Timer {
        interval: 1000
        running: root.expanded
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Native VSync FrameAnimation for buttery 60-144Hz GPU shader motion
    FrameAnimation {
        running: root.expanded
        onTriggered: {
            const dt = Math.min(0.05, Math.max(0.001, frameTime));
            root.orbitPhase = (root.orbitPhase + dt * (0.34 + root.typingEnergy * 1.45)) % 628.3185;
            if (root.typingEnergy > 0.004) root.typingEnergy *= Math.pow(0.08, dt);
            else root.typingEnergy = 0.0;
        }
    }

    Sessions.SessionManagement {
        id: sessions
    }

    // Quick actions open the user's own default apps through the task manager. Nothing passes through a shell.
    readonly property var quickActions: [
        { icon: "system-file-manager", url: "preferred://filemanager", tip: "Files" },
        { icon: "utilities-terminal", url: "preferred://terminal", tip: "Terminal" },
        { icon: "internet-web-browser", url: "preferred://browser", tip: "Browser" },
        { icon: "preferences-system", url: "applications:systemsettings.desktop", tip: "Settings" }
    ]

    TaskManager.TasksModel {
        id: quickTasks
        launcherList: root.quickActions.map(function(action) { return action.url; })
        separateLaunchers: true
        launchInPlace: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled
    }

    function runQuickAction(slot) {
        let row = -1;
        let launchers = 0;
        for (let i = 0; i < quickTasks.count; i++) {
            if (!quickTasks.data(quickTasks.makeModelIndex(i), TaskManager.AbstractTasksModel.IsLauncher)) continue;
            if (launchers === slot) row = i;
            launchers++;
        }
        // Slots are positional, so they are only trusted when every default app resolved.
        if (row < 0 || launchers !== quickActions.length) return;
        quickTasks.requestNewInstance(quickTasks.makeModelIndex(row));
        root.expanded = false;
    }

    Kicker.RootModel {
        id: rootModel
        autoPopulate: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: true
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        appNameFormat: 0
        Component.onCompleted: {
            refresh();
            root.rebuildCategories();
        }
        onCountChanged: root.rebuildCategories()
        onRowsInserted: root.rebuildCategories()
        onRowsRemoved: root.rebuildCategories()
        onModelReset: root.rebuildCategories()
    }

    // Map each category directly to its own AppsModel reference so labels and apps never desync
    function rebuildCategories() {
        const shortMap = {
            "Recent Applications": "Recent",
            "All Applications": "All",
            "Development": "Dev",
            "Education": "Edu",
            "Games": "Games",
            "Graphics": "Graphics",
            "Internet": "Web",
            "Multimedia": "Media",
            "Office": "Office",
            "System": "System",
            "Utilities": "Utils"
        };
        const skip = { "Help": true, "Wine": true, "Lost & Found": true };
        const list = [];
        for (let i = 0; i < rootModel.count; i++) {
            const sub = rootModel.modelForRow(i);
            if (!sub || sub.count <= 0) continue;
            const raw = String(rootModel.data(rootModel.index(i, 0), Qt.DisplayRole) || "");
            if (!raw) continue;
            const low = raw.toLowerCase();
            if (low.indexOf("file") >= 0 || low.indexOf("document") >= 0 || low.indexOf("folder") >= 0) continue;
            if (skip[raw]) continue;
            const isAll = (sub.description === "KICKER_ALL_MODEL" || raw === "All Applications");
            const label = isAll ? "All" : (shortMap[raw] || raw);
            list.push({ model: sub, label: label, isAll: isAll });
        }
        categories = list;
        if (selectedCategory >= list.length) selectedCategory = 0;
        rebuildFiltered();
    }

    readonly property var activeSourceModel: {
        if (categories.length === 0) return null;
        const idx = Math.max(0, Math.min(categories.length - 1, selectedCategory));
        return categories[idx].model;
    }

    readonly property var allAppsModel: {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].isAll) return categories[i].model;
        }
        return categories.length > 0 ? categories[0].model : null;
    }

    ListModel { id: filteredApps }

    readonly property int orbitPageSize: 12
    readonly property int orbitPageCount: Math.max(1, Math.ceil(filteredApps.count / orbitPageSize))

    function rebuildFiltered() {
        filteredApps.clear();
        const q = searchText.trim().toLowerCase();
        const source = q.length > 0 ? allAppsModel : activeSourceModel;
        if (!source) return;
        const n = source.count;
        const ranked = [];
        for (let i = 0; i < n; i++) {
            const idx = source.index(i, 0);
            const name = String(source.data(idx, Qt.DisplayRole) || "");
            const dec = source.data(idx, Qt.DecorationRole);
            const desc = String(source.data(idx, Qt.UserRole + 1) || "");
            if (!name) continue;
            if (q.length === 0) {
                ranked.push({ score: 0, origRow: i, name: name, icon: dec ? String(dec) : "application-x-executable", desc: desc });
            } else {
                const lname = name.toLowerCase();
                const ldesc = desc.toLowerCase();
                let score = -1;
                if (lname === q) score = 100;
                else if (lname.startsWith(q)) score = 80;
                else if (lname.indexOf(q) >= 0) score = 60;
                else if (ldesc.indexOf(q) >= 0) score = 35;
                else {
                    let qi = 0;
                    for (let ci = 0; ci < lname.length && qi < q.length; ci++) {
                        if (lname[ci] === q[qi]) qi++;
                    }
                    if (qi === q.length) score = 20;
                }
                if (score > 0) {
                    ranked.push({ score: score, origRow: i, name: name, icon: dec ? String(dec) : "application-x-executable", desc: desc });
                }
            }
        }
        if (q.length > 0) {
            ranked.sort(function(a, b) { return b.score - a.score || a.name.localeCompare(b.name); });
        }
        const limit = q.length > 0 ? Math.min(ranked.length, 32) : Math.min(ranked.length, 200);
        for (let k = 0; k < limit; k++) {
            filteredApps.append(ranked[k]);
        }
        orbitPage = 0;
        selectedAppIndex = q.length > 0 && filteredApps.count > 0 ? 0 : -1;
    }

    function launchAt(listIdx) {
        if (filteredApps.count === 0 && mathResult.length > 0) {
            copyMathResult();
            return;
        }
        if (listIdx < 0 || listIdx >= filteredApps.count) return;
        const item = filteredApps.get(listIdx);
        const source = searchText.trim().length > 0 ? allAppsModel : activeSourceModel;
        if (source) {
            source.trigger(item.origRow, "", null);
            root.expanded = false;
            root.searchText = "";
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.now = new Date();
            root.mathCopied = false;
            rootModel.refresh();
            root.rebuildCategories();
            root.triggerOrbitBloom();
        } else {
            root.searchText = "";
            root.selectedAppIndex = -1;
            root.orbitPage = 0;
            root.mathCopied = false;
        }
    }
    onSelectedCategoryChanged: {
        typingEnergy = 0.75;
        rebuildFiltered();
        if (orbitalMode && expanded) triggerOrbitBloom();
    }
    onSelectedAppIndexChanged: {
        // Arrow keys can walk past the twelve visible nodes; bring the orbit page along.
        if (orbitalMode && selectedAppIndex >= 0 && searchText.trim().length === 0) {
            const page = Math.floor(selectedAppIndex / orbitPageSize);
            if (page !== orbitPage) orbitPage = page;
        }
    }
    onOrbitPageChanged: {
        typingEnergy = 0.65;
        if (orbitalMode && expanded) triggerOrbitBloom();
    }
    onSearchTextChanged: {
        typingEnergy = 1.0;
        mathCopied = false;
        rebuildFiltered();
    }

    // Top-bar Wabi Sabi Black Hole trigger with smooth VSync orbiting satellite on hover/open
    compactRepresentation: Item {
        id: triggerRoot
        Layout.minimumWidth: 34
        Layout.preferredWidth: 34
        Layout.maximumWidth: 34
        Layout.fillHeight: true

        property real miniAngle: 0.0
        FrameAnimation {
            running: triggerMouse.containsMouse || root.expanded
            onTriggered: triggerRoot.miniAngle = (triggerRoot.miniAngle + frameTime * 2.6) % 6.2831853
        }

        Rectangle {
            id: triggerPill
            anchors.centerIn: parent
            width: 30
            height: 26
            radius: 8
            color: root.expanded
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                : (triggerMouse.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: "tonantzintla-mark"
                scale: triggerMouse.pressed ? 0.90 : (triggerMouse.containsMouse || root.expanded ? 1.10 : 1.0)
                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
            }

            Rectangle {
                visible: triggerMouse.containsMouse || root.expanded
                width: 4
                height: 4
                radius: 2
                color: root.accentColor
                x: triggerPill.width * 0.5 + Math.cos(triggerRoot.miniAngle) * 11 - 2
                y: triggerPill.height * 0.5 + Math.sin(triggerRoot.miniAngle) * 7 - 2
            }

            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // UNIFIED, BORDERLESS GLSL 3D URANUS ORBITAL CONSTELLATION LAUNCHER
    fullRepresentation: Item {
        id: deck
        implicitWidth: 744
        implicitHeight: 556
        Layout.minimumWidth: 680
        Layout.minimumHeight: 500
        Layout.preferredWidth: 744
        Layout.preferredHeight: 556

        onVisibleChanged: {
            if (deck.visible) {
                searchField.forceActiveFocus();
                root.rebuildCategories();
                root.triggerOrbitBloom();
                footerMoon.requestPaint();
            }
        }

        Connections {
            target: root
            function onSelectedAppIndexChanged() {
                if (deck.visible && !root.orbitalMode && root.selectedAppIndex >= 0) {
                    appGrid.positionViewAtIndex(root.selectedAppIndex, GridView.Contain);
                }
                if (deck.visible && root.searchText.trim().length > 0 && root.selectedAppIndex >= 0) {
                    searchList.positionViewAtIndex(root.selectedAppIndex, ListView.Contain);
                }
            }
            function onMoonStepChanged() {
                if (deck.visible) footerMoon.requestPaint();
            }
        }

        HoverHandler {
            onPointChanged: {
                root.cursorNormX = (point.position.x / Math.max(1, deck.width) - 0.5) * 2.0;
                root.cursorNormY = (point.position.y / Math.max(1, deck.height) - 0.5) * 2.0;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ------------------------------------------------------------
            // TOP BAR: WHISPER-CLEAN SEARCH + MINIMAL ICON MODE SWITCHER
            // ------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 11
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.045)
                    border.width: 1
                    border.color: root.searchText.length > 0
                        ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.54)
                        : (searchField.activeFocus
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05))
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        Kirigami.Icon {
                            Layout.preferredWidth: 15
                            Layout.preferredHeight: 15
                            source: "search"
                            isMask: true
                            color: searchField.activeFocus ? root.accentColor : Kirigami.Theme.disabledTextColor
                        }

                        QQC2.TextField {
                            id: searchField
                            Layout.fillWidth: true
                            text: root.searchText
                            onTextChanged: root.searchText = text
                            placeholderText: "Search"
                            placeholderTextColor: Kirigami.Theme.disabledTextColor
                            color: Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 13
                            background: Item {}
                            selectByMouse: true
                            Keys.onEscapePressed: {
                                if (text.length > 0) text = "";
                                else root.expanded = false;
                            }
                            Keys.onReturnPressed: root.launchAt(root.selectedAppIndex >= 0 ? root.selectedAppIndex : 0)
                            Keys.onEnterPressed: root.launchAt(root.selectedAppIndex >= 0 ? root.selectedAppIndex : 0)
                            Keys.onDownPressed: {
                                const step = (root.searchText.trim().length > 0 || root.orbitalMode) ? 1 : 4;
                                const next = root.selectedAppIndex < 0 ? 0 : root.selectedAppIndex + step;
                                root.selectedAppIndex = Math.min(Math.max(0, filteredApps.count - 1), next);
                            }
                            Keys.onUpPressed: {
                                const step = (root.searchText.trim().length > 0 || root.orbitalMode) ? 1 : 4;
                                root.selectedAppIndex = Math.max(0, root.selectedAppIndex - step);
                            }
                            Keys.onRightPressed: {
                                if (root.searchText.trim().length === 0) {
                                    const next = root.selectedAppIndex < 0 ? 0 : root.selectedAppIndex + 1;
                                    root.selectedAppIndex = Math.min(Math.max(0, filteredApps.count - 1), next);
                                }
                            }
                            Keys.onLeftPressed: {
                                if (root.searchText.trim().length === 0) {
                                    root.selectedAppIndex = Math.max(0, root.selectedAppIndex - 1);
                                }
                            }
                        }

                        // Instant calculator readout inline right inside search pill (click to copy)
                        Rectangle {
                            visible: root.mathResult.length > 0
                            Layout.preferredWidth: calcLbl.implicitWidth + 16
                            Layout.preferredHeight: 24
                            radius: 7
                            color: root.accentColor
                            scale: calcPillMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Text {
                                id: calcLbl
                                anchors.centerIn: parent
                                text: root.mathCopied ? "Copied" : ("= " + root.mathResult)
                                color: root.accentFg
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: calcPillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyMathResult()
                            }
                        }

                        // Subtle clear button
                        Kirigami.Icon {
                            visible: root.searchText.length > 0
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "edit-clear"
                            isMask: true
                            color: clearMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                // Minimal icon-only Orbital / Grid toggle with sliding spring pill
                Rectangle {
                    Layout.preferredWidth: 74
                    Layout.preferredHeight: 40
                    radius: 11
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.045)

                    // Sliding active highlight pill driven by SpringAnimation
                    Rectangle {
                        y: 4
                        x: root.orbitalMode ? 4 : 38
                        width: 32
                        height: 32
                        radius: 8
                        color: root.accentColor
                        Behavior on x { SpringAnimation { spring: 6.0; damping: 0.44; epsilon: 0.2 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Orbital mode geometric icon (concentric ring + dot)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Item {
                                anchors.centerIn: parent
                                width: 14; height: 14
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: root.orbitalMode ? root.accentFg : (orbitToggleMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4; height: 4; radius: 2
                                    color: root.orbitalMode ? root.accentFg : (orbitToggleMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                                }
                            }
                            QQC2.ToolTip.visible: orbitToggleMouse.containsMouse
                            QQC2.ToolTip.delay: 450
                            QQC2.ToolTip.text: "Orbit"
                            MouseArea {
                                id: orbitToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.orbitalMode) {
                                        root.orbitalMode = true;
                                        root.triggerOrbitBloom();
                                    }
                                }
                            }
                        }

                        // Grid mode geometric icon (2x2 clean dots)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 3
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 4; height: 4; radius: 1.5
                                        color: !root.orbitalMode ? root.accentFg : (gridToggleMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                                    }
                                }
                            }
                            QQC2.ToolTip.visible: gridToggleMouse.containsMouse
                            QQC2.ToolTip.delay: 450
                            QQC2.ToolTip.text: "Grid"
                            MouseArea {
                                id: gridToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.orbitalMode = false
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // SINGLE-ROW BORDERLESS CATEGORY PILLS WITH SPRING-GLIDING INDICATOR
            // ------------------------------------------------------------
            Flickable {
                visible: root.searchText.trim().length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                contentWidth: Math.max(width, catRow.implicitWidth)
                contentHeight: 28
                clip: true
                interactive: catRow.implicitWidth > width
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    width: catRow.implicitWidth
                    height: 28
                    x: Math.max(0, (parent.width - width) * 0.5)

                    // Spring-gliding lavender active category capsule
                    Rectangle {
                        id: catHighlight
                        visible: root.categories.length > 0 && root.selectedCategory >= 0 && root.selectedCategory < catRepeater.count
                        readonly property Item activeItem: (root.selectedCategory >= 0 && root.selectedCategory < catRepeater.count)
                            ? catRepeater.itemAt(root.selectedCategory)
                            : null
                        x: activeItem ? activeItem.x : 0
                        y: 0
                        width: activeItem ? activeItem.width : 0
                        height: 28
                        radius: 8
                        color: root.accentColor
                        Behavior on x { SpringAnimation { spring: 6.2; damping: 0.44; epsilon: 0.2 } }
                        Behavior on width { SpringAnimation { spring: 6.2; damping: 0.44; epsilon: 0.2 } }
                    }

                    Row {
                        id: catRow
                        spacing: 4

                        Repeater {
                            id: catRepeater
                            model: root.categories
                            Rectangle {
                                id: catPill
                                required property int index
                                required property var modelData
                                readonly property bool active: index === root.selectedCategory
                                width: catLbl.implicitWidth + 18
                                height: 28
                                radius: 8
                                color: (!active && catMouse.containsMouse)
                                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.065)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: catLbl
                                    anchors.centerIn: parent
                                    text: catPill.modelData.label
                                    color: catPill.active ? root.accentFg : (catMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                                    font.family: root.monoFamily
                                    font.pixelSize: 12
                                    font.weight: catPill.active ? Font.Bold : Font.Medium
                                }
                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = catPill.index
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // UNIFIED BORDERLESS HERO STAGE: GLSL 3D RAY-SHADED URANUS CONSTELLATION
            // ------------------------------------------------------------
            Item {
                id: orbitStage
                visible: root.searchText.trim().length === 0 && root.orbitalMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                readonly property int pageStart: root.orbitPage * root.orbitPageSize
                readonly property int pageItems: Math.max(0, Math.min(root.orbitPageSize, filteredApps.count - pageStart))
                readonly property bool hasLock: root.selectedAppIndex >= pageStart && root.selectedAppIndex < pageStart + pageItems

                // Frame-rate-independent damped 3D parallax cursor & magnetic gravity tether tip
                property real smoothCursorX: 0.0
                property real smoothCursorY: 0.0
                property real smoothTargetX: width * 0.5
                property real smoothTargetY: height * 0.47
                property bool tetherInitialized: false

                // Smooth gravitational lock envelope
                property real lockProgress: hasLock ? 1.0 : 0.0
                Behavior on lockProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                onHasLockChanged: {
                    if (hasLock) {
                        const pos = nodePos(root.selectedAppIndex - pageStart, width, height);
                        if (!tetherInitialized || lockProgress < 0.08) {
                            smoothTargetX = pos.x;
                            smoothTargetY = pos.y;
                            tetherInitialized = true;
                        }
                    }
                }

                FrameAnimation {
                    running: orbitStage.visible
                    onTriggered: {
                        const dt = Math.min(0.05, Math.max(0.001, frameTime));
                        const ck = 1.0 - Math.exp(-dt * 8.5);
                        orbitStage.smoothCursorX += (root.cursorNormX - orbitStage.smoothCursorX) * ck;
                        orbitStage.smoothCursorY += (root.cursorNormY - orbitStage.smoothCursorY) * ck;
                        if (orbitStage.hasLock) {
                            const pos = orbitStage.nodePos(root.selectedAppIndex - orbitStage.pageStart, orbitStage.width, orbitStage.height);
                            const tk = 1.0 - Math.exp(-dt * 18.0);
                            orbitStage.smoothTargetX += (pos.x - orbitStage.smoothTargetX) * tk;
                            orbitStage.smoothTargetY += (pos.y - orbitStage.smoothTargetY) * tk;
                        }
                    }
                }

                WheelHandler {
                    onWheel: function(event) {
                        if (root.orbitPageCount <= 1 || event.angleDelta.y === 0) return;
                        const delta = event.angleDelta.y < 0 ? 1 : -1;
                        root.orbitPage = (root.orbitPage + delta + root.orbitPageCount) % root.orbitPageCount;
                        root.selectedAppIndex = -1;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectedAppIndex = -1
                }

                function nodePos(slotIdx, w, h) {
                    const cx = w * 0.5;
                    const cy = h * 0.47;
                    const inner = slotIdx < 5;
                    const ringCount = inner ? Math.min(5, Math.max(1, pageItems)) : Math.max(1, pageItems - 5);
                    const slot = inner ? slotIdx : (slotIdx - 5);
                    const rx = inner ? Math.min(w * 0.25, 168) : Math.min(w * 0.415, 290);
                    const ry = inner ? Math.min(h * 0.305, 122) : Math.min(h * 0.435, 172);
                    const baseAngle = (slot / ringCount) * Math.PI * 2 - Math.PI * 0.5 + (inner ? 0.0 : 0.28);
                    const drift = root.orbitPhase * (inner ? 0.055 : -0.036);
                    // Staggered radial bloom expansion from Uranus on open/switch
                    const stagger = Math.max(0.0, Math.min(1.0, (root.orbitBloom * 1.38) - (inner ? slotIdx * 0.04 : 0.14 + (slotIdx - 5) * 0.035)));
                    const radialScale = 0.22 + 0.78 * stagger;
                    const swirlOffset = (1.0 - stagger) * (inner ? -0.45 : 0.32);
                    return {
                        x: cx + Math.cos(baseAngle + drift + swirlOffset) * rx * radialScale,
                        y: cy + Math.sin(baseAngle + drift + swirlOffset) * ry * radialScale,
                        stagger: stagger
                    };
                }

                // TRUE 3D RAY-SPHERE URANUS + 13-BAND RAY-PLANE ICE RINGS + GRAVITY TETHER SHADER
                ShaderEffect {
                    id: uranusShader
                    anchors.fill: parent
                    property real uTime: root.orbitPhase
                    property real uLock: orbitStage.lockProgress
                    property real uHasTarget: orbitStage.hasLock ? 1.0 : 0.0
                    property real uTyping: root.typingEnergy
                    property vector2d uResolution: Qt.vector2d(width, height)
                    property vector2d uCursor: Qt.vector2d(orbitStage.smoothCursorX, orbitStage.smoothCursorY)
                    property vector2d uTarget: Qt.vector2d(orbitStage.smoothTargetX, orbitStage.smoothTargetY)
                    property color uAccent: root.accentColor
                    property color uText: Kirigami.Theme.textColor
                    fragmentShader: Qt.resolvedUrl("../shaders/uranus_stage.frag.qsb")
                }

                // Center Uranus Holographic Core (shows selected app cleanly on hover/focus)
                Item {
                    id: coreOverlay
                    z: 20
                    width: 88
                    height: 88
                    x: orbitStage.width * 0.5 + orbitStage.smoothCursorX * 1.1 - width * 0.5
                    y: orbitStage.height * 0.47 + orbitStage.smoothCursorY * 1.1 - height * 0.5
                    readonly property var activeItem: (root.selectedAppIndex >= 0 && root.selectedAppIndex < filteredApps.count)
                        ? filteredApps.get(root.selectedAppIndex)
                        : null

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        source: coreOverlay.activeItem ? coreOverlay.activeItem.icon : ""
                        visible: opacity > 0.01
                        opacity: coreOverlay.activeItem !== null ? 1.0 : 0.0
                        scale: coreOverlay.activeItem !== null ? (coreMouse.pressed ? 0.92 : 1.0) : 0.78
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.38 } }
                    }

                    MouseArea {
                        id: coreMouse
                        anchors.fill: parent
                        cursorShape: coreOverlay.activeItem ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (coreOverlay.activeItem) root.launchAt(root.selectedAppIndex)
                    }
                }

                // Collision-free matte obsidian capsule badge directly beneath Uranus on hover/selection
                Rectangle {
                    id: activeBadge
                    z: 30
                    property string cachedName: ""
                    onOpacityChanged: if (opacity <= 0.01) cachedName = ""
                    Connections {
                        target: coreOverlay
                        function onActiveItemChanged() {
                            if (coreOverlay.activeItem) activeBadge.cachedName = coreOverlay.activeItem.name;
                        }
                    }
                    visible: opacity > 0.01 && cachedName.length > 0
                    opacity: coreOverlay.activeItem !== null ? 1.0 : 0.0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: orbitStage.height * 0.47 + 47 + (coreOverlay.activeItem !== null ? 0 : 6)
                    width: Math.min(236, badgeText.implicitWidth + 24)
                    height: 26
                    radius: 9
                    color: Qt.rgba(0.067, 0.067, 0.086, 0.93)
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40)
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on y { SpringAnimation { spring: 6.0; damping: 0.44; epsilon: 0.2 } }
                    Behavior on width { SpringAnimation { spring: 6.5; damping: 0.48; epsilon: 0.2 } }

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 20)
                        horizontalAlignment: Text.AlignHCenter
                        text: activeBadge.cachedName
                        color: Kirigami.Theme.textColor
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }

                // Orbiting App Nodes (Spring-scaled circular medallions with staggered radial bloom)
                Repeater {
                    model: orbitStage.pageItems
                    Rectangle {
                        id: orbNode
                        required property int index
                        readonly property int globalIdx: orbitStage.pageStart + index
                        readonly property var entry: globalIdx < filteredApps.count ? filteredApps.get(globalIdx) : null
                        readonly property var pos: orbitStage.nodePos(index, orbitStage.width, orbitStage.height)
                        readonly property bool selected: globalIdx === root.selectedAppIndex || orbMouse.containsMouse
                        z: selected ? 18 : 6
                        width: 46
                        height: 46
                        radius: 23
                        x: pos.x - 23
                        y: pos.y - 23
                        scale: (0.45 + 0.55 * pos.stagger) * (orbMouse.pressed ? 0.92 : (selected ? 1.18 : 1.0))
                        opacity: pos.stagger * ((orbitStage.hasLock && !selected) ? 0.54 : 1.0)
                        color: selected
                            ? Kirigami.Theme.alternateBackgroundColor
                            : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.92)
                        border.width: selected ? 1.8 : 1
                        border.color: selected
                            ? root.accentColor
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                        Behavior on scale { SpringAnimation { spring: 5.8; damping: 0.36; epsilon: 0.004 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            source: orbNode.entry ? orbNode.entry.icon : "application-x-executable"
                        }

                        MouseArea {
                            id: orbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedAppIndex = orbNode.globalIdx
                            onClicked: root.launchAt(orbNode.globalIdx)
                        }
                    }
                }

                // Subtle orbital pagination bar with quiet chevrons when category has > 12 apps
                Row {
                    visible: root.orbitPageCount > 1
                    z: 25
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 2
                    spacing: 8

                    Text {
                        text: "‹"
                        anchors.verticalCenter: parent.verticalCenter
                        color: pgPrevMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                        opacity: pgPrevMouse.containsMouse ? 1.0 : 0.55
                        font.family: root.monoFamily
                        font.pixelSize: 13
                        font.bold: true
                        MouseArea {
                            id: pgPrevMouse
                            anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.orbitPage = (root.orbitPage - 1 + root.orbitPageCount) % root.orbitPageCount;
                                root.selectedAppIndex = -1;
                            }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            id: pgDots
                            // Eight dots at most; the window slides so the current page always has one.
                            readonly property int first: Math.max(0, Math.min(root.orbitPageCount - 8, root.orbitPage - 3))
                            model: Math.min(8, root.orbitPageCount)
                            Rectangle {
                                id: pgDot
                                required property int index
                                readonly property int page: pgDots.first + index
                                readonly property bool active: page === root.orbitPage
                                width: active ? 18 : 5
                                height: 5
                                radius: 2.5
                                color: active ? root.accentColor : Kirigami.Theme.disabledTextColor
                                opacity: active ? 1.0 : (pgDotMouse.containsMouse ? 0.72 : 0.35)
                                Behavior on width { SpringAnimation { spring: 5.5; damping: 0.42 } }
                                MouseArea {
                                    id: pgDotMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.orbitPage = pgDot.page;
                                        root.selectedAppIndex = -1;
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "›"
                        anchors.verticalCenter: parent.verticalCenter
                        color: pgNextMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                        opacity: pgNextMouse.containsMouse ? 1.0 : 0.55
                        font.family: root.monoFamily
                        font.pixelSize: 13
                        font.bold: true
                        MouseArea {
                            id: pgNextMouse
                            anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.orbitPage = (root.orbitPage + 1) % root.orbitPageCount;
                                root.selectedAppIndex = -1;
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // AIRY BORDERLESS 4-COLUMN GRID (GRID MODE)
            // ------------------------------------------------------------
            GridView {
                id: appGrid
                visible: root.searchText.trim().length === 0 && !root.orbitalMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: 94
                model: filteredApps
                currentIndex: root.selectedAppIndex

                delegate: Item {
                    id: cardWrap
                    required property int index
                    required property string name
                    required property string icon
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight
                    readonly property bool highlighted: index === root.selectedAppIndex || cardMouse.containsMouse

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 12
                        color: cardWrap.highlighted
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.068)
                            : "transparent"
                        border.width: 1
                        border.color: cardWrap.highlighted
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.32)
                            : "transparent"
                        scale: cardMouse.pressed ? 0.96 : 1.0
                        Behavior on color { ColorAnimation { duration: 110 } }
                        Behavior on border.color { ColorAnimation { duration: 110 } }
                        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                source: cardWrap.icon
                                scale: cardWrap.highlighted ? 1.10 : 1.0
                                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: cardWrap.name
                                color: cardWrap.highlighted ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.weight: cardWrap.highlighted ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedAppIndex = cardWrap.index
                            onClicked: root.launchAt(cardWrap.index)
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // CLEAN BORDERLESS SEARCH LIST + CALCULATOR / EMPTY STAGE
            // ------------------------------------------------------------
            Item {
                visible: root.searchText.trim().length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: searchList
                    anchors.fill: parent
                    visible: filteredApps.count > 0
                    clip: true
                    spacing: 4
                    model: filteredApps
                    currentIndex: root.selectedAppIndex

                    delegate: Rectangle {
                        id: resRow
                        required property int index
                        required property string name
                        required property string icon
                        required property string desc
                        readonly property bool active: index === root.selectedAppIndex || resMouse.containsMouse
                        width: searchList.width
                        height: 48
                        radius: 10
                        color: active
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.072)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Serpantinum crisp vertical accent bar on active row
                        Rectangle {
                            visible: resRow.active
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 22
                            radius: 1.5
                            color: root.accentColor
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 9
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.045)
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: resRow.icon
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: resRow.name
                                    color: Kirigami.Theme.textColor
                                    font.family: root.monoFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: resRow.desc.length > 0
                                    Layout.fillWidth: true
                                    text: resRow.desc
                                    color: Kirigami.Theme.disabledTextColor
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: resMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedAppIndex = resRow.index
                            onClicked: root.launchAt(resRow.index)
                        }
                    }
                }

                // Clean Calculator Result Stage when typing arithmetic with no matching apps
                Column {
                    visible: filteredApps.count === 0 && root.mathResult.length > 0
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchText.trim()
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "= " + root.mathResult
                        color: root.accentColor
                        font.family: root.monoFamily
                        font.pixelSize: 42
                        font.weight: Font.Bold
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: copyStageLbl.implicitWidth + 24
                        height: 28
                        radius: 8
                        color: root.mathCopied
                            ? root.accentColor
                            : (copyStageMouse.containsMouse
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.09)
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05))
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: copyStageLbl
                            anchors.centerIn: parent
                            text: root.mathCopied ? "Copied" : "Copy result"
                            color: root.mathCopied ? root.accentFg : Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: copyStageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyMathResult()
                        }
                    }
                }

                // Restrained empty state when no apps match
                Text {
                    visible: filteredApps.count === 0 && root.mathResult.length === 0
                    anchors.centerIn: parent
                    text: "No matching applications"
                    color: Kirigami.Theme.disabledTextColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                }
            }

            // ------------------------------------------------------------
            // WHISPER-THIN FOOTER BAR: TIME + MOON · QUICK ICONS · SESSION ICONS
            // ------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                // Left: clean moon disc + time + date (zero boxes)
                Row {
                    spacing: 8
                    Canvas {
                        id: footerMoon
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const cx = 7, cy = 7, r = 5.4;
                            ctx.fillStyle = "rgba(140,142,158,0.22)";
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                            const phase = root.lunarCycle;
                            const waxing = phase < 0.5;
                            const k = Math.cos(phase * 2.0 * Math.PI);
                            ctx.save();
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
                            ctx.fillStyle = "#eee9dc";
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, waxing ? -Math.PI * 0.5 : Math.PI * 0.5, waxing ? Math.PI * 0.5 : Math.PI * 1.5);
                            ctx.closePath(); ctx.fill();
                            ctx.fillStyle = (k >= 0) ? "#16161d" : "#eee9dc";
                            ctx.beginPath();
                            ctx.ellipse(cx - Math.abs(k) * r, cy - r, Math.abs(k) * r * 2, r * 2);
                            ctx.fill();
                            ctx.restore();
                            ctx.strokeStyle = "rgba(238,233,220,0.22)";
                            ctx.lineWidth = 0.8;
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                        }
                    }
                    Text {
                        text: Qt.formatTime(root.now, "HH:mm")
                        color: Kirigami.Theme.textColor
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Qt.formatDate(root.now, "ddd dd MMM")
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Center: 4 clean icon-only quick actions
                Row {
                    spacing: 4
                    Repeater {
                        model: root.quickActions
                        Rectangle {
                            id: qBtn
                            required property int index
                            required property var modelData
                            width: 28; height: 28; radius: 8
                            color: qMouse.containsMouse
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: qBtn.modelData.icon
                                scale: qMouse.pressed ? 0.90 : (qMouse.containsMouse ? 1.10 : 1.0)
                                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            }
                            QQC2.ToolTip.visible: qMouse.containsMouse
                            QQC2.ToolTip.delay: 450
                            QQC2.ToolTip.text: qBtn.modelData.tip
                            MouseArea {
                                id: qMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runQuickAction(qBtn.index)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right: 4 clean monochrome session icons (zero text boxes)
                Row {
                    spacing: 4
                    Repeater {
                        model: [
                            { id: "lock", icon: "system-lock-screen", danger: false, tip: "Lock" },
                            { id: "sleep", icon: "system-suspend", danger: false, tip: "Sleep" },
                            { id: "reboot", icon: "system-reboot", danger: false, tip: "Reboot" },
                            { id: "power", icon: "system-shutdown", danger: true, tip: "Shut Down" }
                        ]
                        Rectangle {
                            id: sBtn
                            required property var modelData
                            width: 28; height: 28; radius: 8
                            color: sMouse.containsMouse
                                ? (modelData.danger ? Kirigami.Theme.negativeTextColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.085))
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 15; height: 15
                                source: sBtn.modelData.icon
                                isMask: true
                                color: sMouse.containsMouse
                                    ? (sBtn.modelData.danger ? "#101016" : Kirigami.Theme.textColor)
                                    : Kirigami.Theme.disabledTextColor
                                scale: sMouse.pressed ? 0.90 : (sMouse.containsMouse ? 1.10 : 1.0)
                                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            }
                            QQC2.ToolTip.visible: sMouse.containsMouse
                            QQC2.ToolTip.delay: 450
                            QQC2.ToolTip.text: sBtn.modelData.tip
                            MouseArea {
                                id: sMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expanded = false;
                                    if (sBtn.modelData.id === "lock") sessions.lock();
                                    else if (sBtn.modelData.id === "sleep") sessions.suspend();
                                    else if (sBtn.modelData.id === "reboot") sessions.requestReboot();
                                    else if (sBtn.modelData.id === "power") sessions.requestShutdown();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
"""


WORKSPACES_QML = r"""pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"

    readonly property int desktopCount: Math.max(1, Math.min(10, virtualDesktopInfo.numberOfDesktops))
    readonly property int currentIndex: {
        for (let i = 0; i < virtualDesktopInfo.desktopIds.length; i++) {
            if (virtualDesktopInfo.desktopIds[i] === virtualDesktopInfo.currentDesktop) return i;
        }
        return 0;
    }

    // Spring-damped continuous index driving liquid SDF metaball neck stretching
    property real smoothActivePos: currentIndex
    Behavior on smoothActivePos {
        SpringAnimation { spring: 4.8; damping: 0.34; epsilon: 0.002 }
    }

    // Extra room on each side of the active capsule so every gap in the row is the same width.
    readonly property real activeRoom: 9.0

    property int hoveredIndex: -1
    property real hoverAmount: hoveredIndex >= 0 ? 1.0 : 0.0
    Behavior on hoverAmount { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Layout.minimumWidth: pill.implicitWidth
    Layout.preferredWidth: pill.implicitWidth
    Layout.maximumWidth: pill.implicitWidth
    Layout.fillHeight: true

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    // Desktop switching is one typed D-Bus call to KWin: no shell and no helper binary.
    QtObject {
        id: switcher
        property real wheelRemainder: 0
        function activate(oneBasedIndex) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            const target = Math.max(1, Math.min(total, Math.floor(Number(oneBasedIndex) || 1)));
            DBus.SessionBus.asyncCall({
                "service": "org.kde.KWin",
                "path": "/KWin",
                "iface": "org.kde.KWin",
                "member": "setCurrentDesktop",
                "arguments": [new DBus.int32(target)]
            });
        }
        // Touchpads send many small deltas; move one desktop per full wheel notch.
        function wheel(angleDeltaY) {
            wheelRemainder += angleDeltaY;
            if (Math.abs(wheelRemainder) < 120) return;
            step(wheelRemainder < 0 ? 1 : -1);
            wheelRemainder = 0;
        }
        function step(delta) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            if (total <= 1) return;
            const cur = root.currentIndex + 1;
            const next = Math.max(1, Math.min(total, cur + (delta > 0 ? 1 : -1)));
            if (next !== cur) activate(next);
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: 32 + root.activeRoom * 2 + (root.desktopCount - 1) * 20
        implicitHeight: 26
        radius: 8
        color: groupHover.hovered
            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.055)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        HoverHandler { id: groupHover }

        WheelHandler {
            onWheel: function(event) {
                switcher.wheel(event.angleDelta.y);
            }
        }

        // GPU GLSL Liquid Metaball SDF Indicator
        ShaderEffect {
            anchors.fill: parent
            property real uTime: 0.0
            property real uCount: root.desktopCount
            property real uActivePos: root.smoothActivePos
            property real uHoverIdx: root.hoveredIndex
            property real uHoverAmt: root.hoverAmount
            property vector2d uResolution: Qt.vector2d(width, height)
            property color uAccent: root.accentColor
            property color uText: Kirigami.Theme.textColor
            property color uMuted: Kirigami.Theme.disabledTextColor
            fragmentShader: Qt.resolvedUrl("../shaders/workspaces_metaball.frag.qsb")
        }

        // Crisp stable hit targets layered over each desktop node
        Repeater {
            model: root.desktopCount
            MouseArea {
                id: hitZone
                required property int index
                readonly property real padX: 16.0
                readonly property real stepX: root.desktopCount > 1 ? (pill.width - padX * 2.0 - root.activeRoom * 2.0) / (root.desktopCount - 1) : 0.0
                readonly property real shift: root.activeRoom * (Math.max(-1, Math.min(1, index - root.currentIndex)) + 1)
                readonly property real cx: root.desktopCount > 1 ? (padX + index * stepX + shift) : (pill.width * 0.5)
                readonly property real reach: index === root.currentIndex ? 14 : 10
                x: cx - reach
                y: 0
                width: reach * 2
                height: pill.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = hitZone.index
                onExited: if (root.hoveredIndex === hitZone.index) root.hoveredIndex = -1
                onClicked: switcher.activate(hitZone.index + 1)
            }
        }
    }
}
"""


MEDIA_QML = r"""pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var player: mprisModel.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === 2
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family

    property real progressRatio: 0.0
    property real trackLengthUs: 0.0
    property string posLabel: "00:00"
    property string lenLabel: "--:--"
    property bool isSeeking: false

    readonly property int trackSeed: {
        const s = hasPlayer ? String(player.track || player.identity || "tonantzintla") : "tonantzintla";
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i);
            h = (h * 16777619) >>> 0;
        }
        return h;
    }

    function fmtUs(us) {
        const secs = Math.max(0, Math.floor((Number(us) || 0) / 1000000));
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // The player picks this URL, and a web page can be the player. Only ordinary image locations are loaded.
    function safeArtUrl(url) {
        const value = String(url || "");
        return (/^(file|https?):\/\//i.test(value) || /^data:image\//i.test(value)) ? value : "";
    }

    Mpris.Mpris2Model {
        id: mprisModel
    }

    Timer {
        interval: 1000
        running: root.expanded && root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.hasPlayer || root.isSeeking) return;
            root.player.updatePosition();
            const len = Number(root.player.length) || 0;
            const pos = Number(root.player.position) || 0;
            root.trackLengthUs = len;
            root.progressRatio = len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0;
            root.posLabel = root.fmtUs(pos);
            root.lenLabel = len > 0 ? root.fmtUs(len) : "--:--";
        }
    }

    compactRepresentation: Item {
        Layout.minimumWidth: root.hasPlayer ? pill.implicitWidth : 0
        Layout.preferredWidth: root.hasPlayer ? pill.implicitWidth : 0
        Layout.maximumWidth: root.hasPlayer ? 290 : 0
        Layout.fillHeight: true

        Rectangle {
            id: pill
            visible: root.hasPlayer
            anchors.centerIn: parent
            implicitWidth: Math.min(284, contentRow.implicitWidth + 14)
            implicitHeight: 28
            radius: 8
            color: mediaHover.hovered || root.expanded ? Kirigami.Theme.alternateBackgroundColor : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: mediaHover }

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 7

                // Truly circular rotating vinyl disc emblem (anti-aliased Canvas circular clip, GPU rotated)
                Item {
                    id: miniVinyl
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22

                    Image {
                        id: miniArtSrc
                        source: root.hasPlayer ? root.safeArtUrl(root.player.artUrl) : ""
                        visible: false
                        asynchronous: true
                        onStatusChanged: miniVinylCanvas.requestPaint()
                        onSourceChanged: miniVinylCanvas.requestPaint()
                    }

                    Canvas {
                        id: miniVinylCanvas
                        anchors.fill: parent
                        antialiasing: true

                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 6000
                            loops: Animation.Infinite
                            running: root.hasPlayer
                            paused: running && !root.playing
                        }

                        Connections {
                            target: root
                            function onPlayingChanged() { miniVinylCanvas.requestPaint(); }
                            function onAccentColorChanged() { miniVinylCanvas.requestPaint(); }
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const w = width, h = height;
                            const cx = w * 0.5, cy = h * 0.5, r = w * 0.5 - 0.5;
                            ctx.clearRect(0, 0, w, h);

                            ctx.save();
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.clip();

                            ctx.fillStyle = "#0b0b11";
                            ctx.fillRect(0, 0, w, h);

                            if (miniArtSrc.status === Image.Ready && miniArtSrc.implicitWidth > 0) {
                                const iw = miniArtSrc.implicitWidth, ih = miniArtSrc.implicitHeight;
                                const sc = Math.max(w / iw, h / ih);
                                const dw = iw * sc, dh = ih * sc;
                                ctx.drawImage(miniArtSrc, (w - dw) * 0.5, (h - dh) * 0.5, dw, dh);
                            }

                            ctx.strokeStyle = "rgba(255,255,255,0.16)";
                            ctx.lineWidth = 0.7;
                            ctx.beginPath(); ctx.arc(cx, cy, r - 2.6, 0, Math.PI * 2); ctx.stroke();

                            ctx.fillStyle = "#0b0b11";
                            ctx.beginPath(); ctx.arc(cx, cy, 3.0, 0, Math.PI * 2); ctx.fill();
                            ctx.strokeStyle = root.accentColor;
                            ctx.lineWidth = 1.0;
                            ctx.beginPath(); ctx.arc(cx, cy, 3.0, 0, Math.PI * 2); ctx.stroke();
                            ctx.restore();

                            ctx.strokeStyle = root.playing
                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.75)
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22);
                            ctx.lineWidth = 1.0;
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: miniArtSrc.status !== Image.Ready
                        text: "♪"
                        color: root.accentColor
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                // Live 3-bar acoustic micro-visualizer
                Row {
                    visible: root.playing
                    spacing: 1.5
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 3
                        Item {
                            id: eqSlot
                            required property int index
                            width: 2
                            height: 12
                            Rectangle {
                                width: 2; height: 4; radius: 1
                                anchors.bottom: parent.bottom
                                color: root.accentColor
                                SequentialAnimation on height {
                                    running: root.playing
                                    loops: Animation.Infinite
                                    NumberAnimation { to: eqSlot.index === 1 ? 11 : (eqSlot.index === 0 ? 9 : 8); duration: 240 + eqSlot.index * 95; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 3; duration: 220 + eqSlot.index * 80; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 148
                    text: root.hasPlayer ? (root.player.track || root.player.identity || "Media") : ""
                    color: root.playing ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "media-skip-backward"
                    isMask: true
                    color: prevMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.Previous()
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 6
                    color: playMouse.containsMouse ? root.accentColor : Kirigami.Theme.alternateBackgroundColor
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        isMask: true
                        color: playMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.PlayPause()
                    }
                }
                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "media-skip-forward"
                    isMask: true
                    color: nextMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.Next()
                    }
                }
            }
        }
    }

    // ULTRA-CLEAN GLSL ANISOTROPIC VINYL & LIVING HARMONIC WAVEFORM DECK
    fullRepresentation: Item {
        id: deckRoot
        implicitWidth: 344
        implicitHeight: 214

        property real hoverRatio: -1.0
        readonly property bool hoveringWave: hoverRatio >= 0.0
        property real vinylAngle: 0.45
        property real waveTime: 0.0
        property real playBlend: root.playing ? 1.0 : 0.0
        Behavior on playBlend { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        FrameAnimation {
            running: deckRoot.visible && root.hasPlayer
            onTriggered: {
                const dt = Math.min(0.05, Math.max(0.001, frameTime));
                deckRoot.waveTime = (deckRoot.waveTime + dt) % 1000.0;
                if (deckRoot.playBlend > 0.005) {
                    deckRoot.vinylAngle = (deckRoot.vinylAngle + dt * 1.25 * deckRoot.playBlend) % 628.3185;
                }
            }
        }

        // Pinned to the top so a resized popup keeps its rhythm instead of spreading the rows apart.
        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Peeking GPU anisotropic vinyl record + truly rounded album sleeve
                Item {
                    Layout.preferredWidth: 114
                    Layout.preferredHeight: 76

                    // GLSL anisotropic brushed-vinyl shader with spring slide-out
                    ShaderEffect {
                        id: vinylShader
                        width: 72; height: 72
                        x: root.playing ? 40 : 10
                        y: 2
                        Behavior on x { SpringAnimation { spring: 3.8; damping: 0.42; epsilon: 0.25 } }

                        property real uAngle: deckRoot.vinylAngle
                        property real uPlaying: deckRoot.playBlend
                        property vector2d uResolution: Qt.vector2d(width, height)
                        property color uAccent: root.accentColor
                        fragmentShader: Qt.resolvedUrl("../shaders/vinyl_disc.frag.qsb")
                    }

                    // Soft sleeve shadow cast onto the peeking vinyl
                    Rectangle {
                        z: 1
                        x: 72; y: 4
                        width: 14; height: 68
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.58) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // True anti-aliased rounded-corner album sleeve (Canvas rounded clip, zero square corners)
                    Item {
                        z: 2
                        width: 76; height: 76

                        Image {
                            id: deckArtSrc
                            source: root.hasPlayer ? root.safeArtUrl(root.player.artUrl) : ""
                            visible: false
                            asynchronous: true
                            onStatusChanged: sleeveCanvas.requestPaint()
                            onSourceChanged: sleeveCanvas.requestPaint()
                        }

                        Canvas {
                            id: sleeveCanvas
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                const w = width, h = height, r = 11;
                                ctx.clearRect(0, 0, w, h);

                                function roundedPath(pad, rad) {
                                    ctx.beginPath();
                                    ctx.moveTo(pad + rad, pad);
                                    ctx.lineTo(w - pad - rad, pad);
                                    ctx.quadraticCurveTo(w - pad, pad, w - pad, pad + rad);
                                    ctx.lineTo(w - pad, h - pad - rad);
                                    ctx.quadraticCurveTo(w - pad, h - pad, w - pad - rad, h - pad);
                                    ctx.lineTo(pad + rad, h - pad);
                                    ctx.quadraticCurveTo(pad, h - pad, pad, h - pad - rad);
                                    ctx.lineTo(pad, pad + rad);
                                    ctx.quadraticCurveTo(pad, pad, pad + rad, pad);
                                    ctx.closePath();
                                }

                                ctx.save();
                                roundedPath(0, r);
                                ctx.clip();

                                ctx.fillStyle = Kirigami.Theme.alternateBackgroundColor;
                                ctx.fillRect(0, 0, w, h);

                                if (deckArtSrc.status === Image.Ready && deckArtSrc.implicitWidth > 0) {
                                    const iw = deckArtSrc.implicitWidth, ih = deckArtSrc.implicitHeight;
                                    const sc = Math.max(w / iw, h / ih);
                                    const dw = iw * sc, dh = ih * sc;
                                    ctx.drawImage(deckArtSrc, (w - dw) * 0.5, (h - dh) * 0.5, dw, dh);
                                }
                                ctx.restore();

                                roundedPath(0.5, r - 0.5);
                                ctx.strokeStyle = "rgba(255,255,255,0.12)";
                                ctx.lineWidth = 1.0;
                                ctx.stroke();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: deckArtSrc.status !== Image.Ready
                            text: "♪"
                            color: root.accentColor
                            font.pixelSize: 26
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.track || "No Track") : "Nothing Playing"
                        color: Kirigami.Theme.textColor
                        font.family: root.monoFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.artist || root.player.identity || "") : ""
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // GLSL Living 32-Bar Harmonic Waveform Seekbar with Gaussian Hover Wave & Drag Scrub
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Item {
                    id: waveTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    ShaderEffect {
                        anchors.fill: parent
                        property real uTime: deckRoot.waveTime
                        property real uProgress: root.progressRatio
                        property real uHoverRatio: deckRoot.hoverRatio
                        property real uPlaying: deckRoot.playBlend
                        property real uSeed: (root.trackSeed % 97)
                        property vector2d uResolution: Qt.vector2d(width, height)
                        property color uAccent: root.accentColor
                        property color uText: Kirigami.Theme.textColor
                        fragmentShader: Qt.resolvedUrl("../shaders/media_wave.frag.qsb")
                    }

                    MouseArea {
                        id: waveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.hasPlayer && root.player.canSeek && root.trackLengthUs > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function ratioForX(mx) {
                            return Math.max(0, Math.min(1, mx / Math.max(1, waveTrack.width)));
                        }
                        function commitSeek(ratio) {
                            if (!root.hasPlayer || !root.player.canSeek) return;
                            const len = Number(root.player.length) || 0;
                            if (len <= 0) return;
                            const target = ratio * len;
                            const cur = Number(root.player.position) || 0;
                            root.player.Seek(Math.round(target - cur));
                            root.progressRatio = ratio;
                            root.posLabel = root.fmtUs(target);
                        }
                        onPositionChanged: function(mouse) {
                            const r = ratioForX(mouse.x);
                            deckRoot.hoverRatio = r;
                            if (pressed && root.hasPlayer && root.trackLengthUs > 0) {
                                root.progressRatio = r;
                                root.posLabel = root.fmtUs(r * root.trackLengthUs);
                            }
                        }
                        onExited: if (!pressed) deckRoot.hoverRatio = -1.0
                        onPressed: function(mouse) {
                            if (!root.hasPlayer || !root.player.canSeek || root.trackLengthUs <= 0) return;
                            root.isSeeking = true;
                            const r = ratioForX(mouse.x);
                            deckRoot.hoverRatio = r;
                            root.progressRatio = r;
                            root.posLabel = root.fmtUs(r * root.trackLengthUs);
                        }
                        onReleased: function(mouse) {
                            if (root.isSeeking) {
                                commitSeek(ratioForX(mouse.x));
                                root.isSeeking = false;
                            }
                            if (!containsMouse) deckRoot.hoverRatio = -1.0;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (deckRoot.hoveringWave && root.trackLengthUs > 0)
                            ? root.fmtUs(deckRoot.hoverRatio * root.trackLengthUs)
                            : root.posLabel
                        color: deckRoot.hoveringWave && root.trackLengthUs > 0 ? root.accentColor : Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.lenLabel
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                    }
                }
            }

            // Crisp geometric transport controls with spring press feel
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 34; radius: 9
                    color: deckPrev.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    scale: deckPrev.pressed ? 0.90 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "media-skip-backward"
                        isMask: true
                        color: deckPrev.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }
                    MouseArea { id: deckPrev; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.Previous() }
                }
                Rectangle {
                    Layout.preferredWidth: 54; Layout.preferredHeight: 36; radius: 11
                    color: root.accentColor
                    scale: deckPlay.pressed ? 0.92 : (deckPlay.containsMouse ? 1.07 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        isMask: true
                        color: root.accentFg
                    }
                    MouseArea { id: deckPlay; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.PlayPause() }
                }
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 34; radius: 9
                    color: deckNext.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    scale: deckNext.pressed ? 0.90 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "media-skip-forward"
                        isMask: true
                        color: deckNext.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }
                    MouseArea { id: deckNext; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.Next() }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
"""


CLOCK_QML = r"""pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    property date now: new Date()
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family

    readonly property real lunarCycle: {
        const refMs = Date.UTC(2000, 0, 6, 18, 14, 0);
        const days = (now.getTime() - refMs) / 86400000.0;
        const synodic = 29.53058867;
        let phase = (days % synodic) / synodic;
        if (phase < 0) phase += 1.0;
        return phase;
    }
    // The disc only changes visibly every few hours; repaint on that step, not every second.
    readonly property int moonStep: Math.round(lunarCycle * 240)

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    compactRepresentation: Item {
        Layout.minimumWidth: clockPill.implicitWidth
        Layout.preferredWidth: clockPill.implicitWidth
        Layout.maximumWidth: clockPill.implicitWidth
        Layout.fillHeight: true

        Rectangle {
            id: clockPill
            anchors.centerIn: parent
            implicitWidth: clockRow.implicitWidth + 18
            implicitHeight: 26
            radius: 8
            color: clockMouse.containsMouse || root.expanded ? Kirigami.Theme.alternateBackgroundColor : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
                Rectangle {
                    width: 4; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accentColor
                }
                Text {
                    text: Qt.formatDate(root.now, "ddd dd MMM")
                    color: Kirigami.Theme.disabledTextColor
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Canvas {
                    id: barMoon
                    width: 12; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    Connections {
                        target: root
                        function onMoonStepChanged() { barMoon.requestPaint(); }
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const cx = 6, cy = 6, r = 4.6;
                        ctx.fillStyle = "rgba(140,142,158,0.22)";
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                        const phase = root.lunarCycle;
                        const waxing = phase < 0.5;
                        const k = Math.cos(phase * 2.0 * Math.PI);
                        ctx.save();
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
                        ctx.fillStyle = "#eee9dc";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, waxing ? -Math.PI * 0.5 : Math.PI * 0.5, waxing ? Math.PI * 0.5 : Math.PI * 1.5);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = (k >= 0) ? "#16161d" : "#eee9dc";
                        ctx.beginPath();
                        ctx.ellipse(cx - Math.abs(k) * r, cy - r, Math.abs(k) * r * 2, r * 2);
                        ctx.fill();
                        ctx.restore();
                        ctx.strokeStyle = "rgba(238,233,220,0.24)";
                        ctx.lineWidth = 0.75;
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                    }
                }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // ULTRA-CLEAN GLSL SCALLOPED CHRONOMETER & CALENDAR POPUP
    fullRepresentation: Item {
        id: calRoot
        implicitWidth: 312
        implicitHeight: 382
        property int viewYear: root.now.getFullYear()
        property int viewMonth: root.now.getMonth()
        readonly property bool isCurrentMonth: viewYear === root.now.getFullYear() && viewMonth === root.now.getMonth()
        // Week start and weekend follow the system region instead of assuming Monday and Sat/Sun.
        readonly property int firstDay: Qt.locale().firstDayOfWeek
        readonly property var workDays: Qt.locale().weekDays

        // Continuous sub-second timestamp for buttery 60-144Hz sweeping golden second comet
        property real smoothSecs: root.now.getSeconds() + root.now.getMilliseconds() / 1000.0
        property real smoothMins: root.now.getMinutes() + smoothSecs / 60.0
        property real smoothHrs: (root.now.getHours() % 12) + smoothMins / 60.0

        FrameAnimation {
            running: calRoot.visible
            onTriggered: {
                const d = new Date();
                const s = d.getSeconds() + d.getMilliseconds() / 1000.0;
                const m = d.getMinutes() + s / 60.0;
                calRoot.smoothSecs = s;
                calRoot.smoothMins = m;
                calRoot.smoothHrs = (d.getHours() % 12) + m / 60.0;
            }
        }

        Connections {
            target: root
            function onMoonStepChanged() {
                if (calRoot.visible) popupMoon.requestPaint();
            }
        }
        onVisibleChanged: {
            if (calRoot.visible) popupMoon.requestPaint();
        }

        function shiftMonth(delta) {
            const d = new Date(viewYear, viewMonth + delta, 1);
            viewYear = d.getFullYear();
            viewMonth = d.getMonth();
        }
        function cellDate(cellIndex) {
            const first = new Date(viewYear, viewMonth, 1);
            const lead = (first.getDay() - firstDay + 7) % 7;
            return new Date(viewYear, viewMonth, 1 - lead + cellIndex);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // GPU SDF 12-Lobed Scalloped Chronometer Shader
                ShaderEffect {
                    id: analogDial
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    property real uHourAngle: (calRoot.smoothHrs / 12.0) * 6.2831853 - 1.5707963
                    property real uMinAngle: (calRoot.smoothMins / 60.0) * 6.2831853 - 1.5707963
                    property real uSecAngle: (calRoot.smoothSecs / 60.0) * 6.2831853 - 1.5707963
                    property vector2d uResolution: Qt.vector2d(width, height)
                    property color uAccent: root.accentColor
                    property color uText: Kirigami.Theme.textColor
                    property color uSurface: Kirigami.Theme.alternateBackgroundColor
                    fragmentShader: Qt.resolvedUrl("../shaders/clock_dial.frag.qsb")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        text: Qt.formatTime(root.now, "HH:mm:ss")
                        color: root.accentColor
                        font.family: root.monoFamily
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                    Row {
                        spacing: 7
                        Canvas {
                            id: popupMoon
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const cx = 6.5, cy = 6.5, r = 5.0;
                                ctx.fillStyle = "rgba(140,142,158,0.22)";
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                                const phase = root.lunarCycle;
                                const waxing = phase < 0.5;
                                const k = Math.cos(phase * 2.0 * Math.PI);
                                ctx.save();
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
                                ctx.fillStyle = "#eee9dc";
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, waxing ? -Math.PI * 0.5 : Math.PI * 0.5, waxing ? Math.PI * 0.5 : Math.PI * 1.5);
                                ctx.closePath(); ctx.fill();
                                ctx.fillStyle = (k >= 0) ? "#16161d" : "#eee9dc";
                                ctx.beginPath();
                                ctx.ellipse(cx - Math.abs(k) * r, cy - r, Math.abs(k) * r * 2, r * 2);
                                ctx.fill();
                                ctx.restore();
                                ctx.strokeStyle = "rgba(238,233,220,0.24)";
                                ctx.lineWidth = 0.75;
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                            }
                        }
                        Text {
                            text: Qt.formatDate(root.now, "dddd, MMM d")
                            color: Kirigami.Theme.disabledTextColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                    color: prevMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "‹"; color: prevMo.containsMouse ? root.accentColor : Kirigami.Theme.textColor; font.family: root.monoFamily; font.pixelSize: 15; font.bold: true }
                    MouseArea { id: prevMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(-1) }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(calRoot.viewYear, calRoot.viewMonth, 1), "MMMM yyyy")
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: !calRoot.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            calRoot.viewYear = root.now.getFullYear();
                            calRoot.viewMonth = root.now.getMonth();
                        }
                    }
                }
                Rectangle {
                    visible: !calRoot.isCurrentMonth
                    Layout.preferredWidth: todayTxt.implicitWidth + 12; Layout.preferredHeight: 22; radius: 6
                    color: Kirigami.Theme.alternateBackgroundColor
                    Text { id: todayTxt; anchors.centerIn: parent; text: "Today"; color: root.accentColor; font.family: root.monoFamily; font.pixelSize: 10; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { calRoot.viewYear = root.now.getFullYear(); calRoot.viewMonth = root.now.getMonth(); } }
                }
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                    color: nextMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "›"; color: nextMo.containsMouse ? root.accentColor : Kirigami.Theme.textColor; font.family: root.monoFamily; font.pixelSize: 15; font.bold: true }
                    MouseArea { id: nextMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(1) }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        readonly property int weekday: (calRoot.firstDay + index) % 7
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(weekday, Locale.NarrowFormat)
                        color: calRoot.workDays.indexOf(weekday) < 0
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.70)
                            : Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y !== 0) calRoot.shiftMonth(event.angleDelta.y < 0 ? 1 : -1);
                    }
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 7
                    rowSpacing: 3
                    columnSpacing: 3
                    Repeater {
                        model: 42
                        Rectangle {
                            id: dayCell
                            required property int index
                            readonly property date dt: calRoot.cellDate(index)
                            readonly property bool inMonth: dt.getMonth() === calRoot.viewMonth
                            readonly property bool isToday: dt.getFullYear() === root.now.getFullYear() && dt.getMonth() === root.now.getMonth() && dt.getDate() === root.now.getDate()
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 8
                            color: isToday
                                ? root.accentColor
                                : (dayHover.hovered && inMonth ? Kirigami.Theme.alternateBackgroundColor : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }
                            HoverHandler { id: dayHover }
                            Text {
                                anchors.centerIn: parent
                                text: dayCell.dt.getDate()
                                color: dayCell.isToday ? root.accentFg : Kirigami.Theme.textColor
                                opacity: dayCell.isToday ? 1.0 : (dayCell.inMonth ? 0.92 : 0.24)
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.weight: dayCell.isToday ? Font.Bold : Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
"""


STATUS_QML = r"""pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.volume as PlasmaVolume
import org.kde.plasma.private.battery as PlasmaBattery

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var sink: PlasmaVolume.PreferredDevice.sink
    readonly property int volPercent: sink ? Math.round((sink.volume / 65536.0) * 100) : 0
    readonly property bool volMuted: sink ? sink.muted : false
    readonly property string volIcon: {
        if (volMuted || volPercent <= 0) return "audio-volume-muted";
        if (volPercent < 34) return "audio-volume-low";
        if (volPercent < 67) return "audio-volume-medium";
        return "audio-volume-high";
    }
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family
    readonly property color textFg: (0.2126 * linChannel(Kirigami.Theme.textColor.r) + 0.7152 * linChannel(Kirigami.Theme.textColor.g) + 0.0722 * linChannel(Kirigami.Theme.textColor.b)) > 0.34 ? "#101016" : "#f8f7fc"

    PlasmaBattery.BatteryControlModel {
        id: batteryModel
    }

    compactRepresentation: Item {
        Layout.minimumWidth: pillsRow.implicitWidth + 8
        Layout.preferredWidth: pillsRow.implicitWidth + 8
        Layout.maximumWidth: pillsRow.implicitWidth + 8
        Layout.fillHeight: true

        Row {
            id: pillsRow
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                visible: root.sink !== null && root.sink !== undefined
                width: volLabel.implicitWidth + 18
                height: 24
                radius: 7
                color: root.volMuted ? Kirigami.Theme.alternateBackgroundColor : root.accentColor
                opacity: volMouse.containsMouse ? 0.90 : 1.0
                scale: volMouse.pressed ? 0.95 : 1.0
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                Text {
                    id: volLabel
                    anchors.centerIn: parent
                    text: root.volMuted ? "MUTE" : ("VOL " + root.volPercent + "%")
                    color: root.volMuted ? Kirigami.Theme.disabledTextColor : root.accentFg
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.sink) root.sink.muted = !root.sink.muted;
                        } else {
                            root.expanded = !root.expanded;
                        }
                    }
                    onWheel: function(wheel) {
                        if (!root.sink) return;
                        const delta = wheel.angleDelta.y > 0 ? 3277 : -3277;
                        root.sink.volume = Math.max(0, Math.min(98304, root.sink.volume + delta));
                    }
                }
            }

            Rectangle {
                visible: batteryModel.hasBatteries
                width: batLabel.implicitWidth + 18
                height: 24
                radius: 7
                color: batteryModel.percent <= 20 && !batteryModel.pluggedIn ? Kirigami.Theme.negativeTextColor : (batteryModel.pluggedIn ? Kirigami.Theme.textColor : Kirigami.Theme.alternateBackgroundColor)
                Text {
                    id: batLabel
                    anchors.centerIn: parent
                    text: (batteryModel.pluggedIn ? "⚡ " : "BAT ") + batteryModel.percent + "%"
                    color: batteryModel.pluggedIn ? root.textFg : (batteryModel.percent <= 20 ? "#101016" : Kirigami.Theme.textColor)
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }
        }
    }

    // ULTRA-CLEAN GLSL LIQUID-PRISM TACTILE AUDIO & POWER POPUP
    fullRepresentation: Item {
        id: statusRoot
        implicitWidth: 304
        implicitHeight: batteryModel.hasBatteries ? 212 : 156

        property real faderTime: 0.0
        property real faderEnergy: 0.0
        property real mutedBlend: root.volMuted ? 1.0 : 0.0
        Behavior on mutedBlend { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        FrameAnimation {
            running: statusRoot.visible
            onTriggered: {
                const dt = Math.min(0.05, Math.max(0.001, frameTime));
                statusRoot.faderTime = (statusRoot.faderTime + dt) % 1000.0;
                if (statusRoot.faderEnergy > 0.004) statusRoot.faderEnergy *= Math.pow(0.05, dt);
                else statusRoot.faderEnergy = 0.0;
            }
        }

        Connections {
            target: root
            function onVolPercentChanged() {
                statusRoot.faderEnergy = 1.0;
            }
        }

        // Pinned to the top so a resized popup keeps its rhythm instead of spreading the rows apart.
        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.sink ? (root.sink.description || root.sink.name || "Output") : "Audio"
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    text: root.volMuted ? "Muted" : (root.volPercent + "%")
                    color: root.volMuted ? Kirigami.Theme.negativeTextColor : root.accentColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            // GPU GLSL Liquid-Prism Tactile Volume Fader
            Item {
                id: sliderTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                readonly property real fillRatio: Math.max(0.0, Math.min(1.0, root.volPercent / 100.0))
                property real displayRatio: fillRatio
                Behavior on displayRatio {
                    enabled: !sliderMouse.pressed
                    SpringAnimation { spring: 6.2; damping: 0.48; epsilon: 0.002 }
                }

                property real pressedBlend: sliderMouse.pressed ? 1.0 : 0.0
                Behavior on pressedBlend { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                ShaderEffect {
                    anchors.fill: parent
                    property real uTime: statusRoot.faderTime
                    property real uRatio: sliderTrack.displayRatio
                    property real uMuted: statusRoot.mutedBlend
                    property real uPressed: sliderTrack.pressedBlend
                    property real uEnergy: statusRoot.faderEnergy
                    property vector2d uResolution: Qt.vector2d(width, height)
                    property color uAccent: root.accentColor
                    property color uAccentFg: root.accentFg
                    property color uSurface: Kirigami.Theme.alternateBackgroundColor
                    property color uText: Kirigami.Theme.textColor
                    fragmentShader: Qt.resolvedUrl("../shaders/status_fader.frag.qsb")
                }

                // Embedded dynamic speaker icon with auto-contrast over active fill
                Kirigami.Icon {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    source: root.volIcon
                    isMask: true
                    color: (!root.volMuted && sliderTrack.displayRatio * sliderTrack.width > 28) ? root.accentFg : Kirigami.Theme.disabledTextColor
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function setFromX(mx) {
                        if (!root.sink) return;
                        const ratio = Math.max(0, Math.min(1, mx / Math.max(1, sliderTrack.width)));
                        root.sink.muted = false;
                        root.sink.volume = Math.round(ratio * 65536);
                        statusRoot.faderEnergy = 0.85;
                    }
                    onPressed: function(mouse) { setFromX(mouse.x); }
                    onPositionChanged: function(mouse) { if (pressed) setFromX(mouse.x); }
                    onWheel: function(wheel) {
                        if (!root.sink) return;
                        const delta = wheel.angleDelta.y > 0 ? 3277 : -3277;
                        root.sink.muted = false;
                        root.sink.volume = Math.max(0, Math.min(65536, root.sink.volume + delta));
                        statusRoot.faderEnergy = 1.0;
                    }
                }
            }

            // Clean Battery readout + slim charge bar when hardware battery is present
            ColumnLayout {
                visible: batteryModel.hasBatteries
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: batteryModel.pluggedIn ? "Charging" : "Battery"
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                    Text {
                        text: batteryModel.percent + "%"
                        color: batteryModel.percent <= 20 && !batteryModel.pluggedIn
                            ? Kirigami.Theme.negativeTextColor
                            : (batteryModel.pluggedIn ? Kirigami.Theme.positiveTextColor : root.accentColor)
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Kirigami.Theme.alternateBackgroundColor
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, batteryModel.percent / 100.0))
                        radius: 3
                        color: batteryModel.percent <= 20 && !batteryModel.pluggedIn
                            ? Kirigami.Theme.negativeTextColor
                            : (batteryModel.pluggedIn ? Kirigami.Theme.positiveTextColor : root.accentColor)
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: root.volMuted
                        ? root.accentColor
                        : (muteMouse.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.11) : Kirigami.Theme.alternateBackgroundColor)
                    scale: muteMouse.pressed ? 0.94 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14
                            source: root.volMuted ? "audio-volume-high" : "audio-volume-muted"
                            isMask: true
                            color: root.volMuted ? root.accentFg : Kirigami.Theme.textColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.volMuted ? "Unmute" : "Mute"
                            color: root.volMuted ? root.accentFg : Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sink) root.sink.muted = !root.sink.muted
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: cfgMouse.containsMouse ? root.accentColor : Kirigami.Theme.alternateBackgroundColor
                    scale: cfgMouse.pressed ? 0.94 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14
                            source: "configure"
                            isMask: true
                            color: cfgMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Mixer"
                            color: cfgMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: cfgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            KCMUtils.KCMLauncher.openSystemSettings("kcm_pulseaudio");
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
"""


SPLASH_QML = r"""import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "{void_}"
    property int stage: 0
    property real phase: 0.0

    FrameAnimation {
        running: true
        onTriggered: root.phase = (root.phase + frameTime) % 628.3185
    }

    // GPU GLSL Gravitational Astrolabe & Starfield Shader
    ShaderEffect {
        anchors.fill: parent
        property real uTime: root.phase
        property real uProgress: Math.min(1, Math.max(0.14, root.stage / 6))
        property vector2d uResolution: Qt.vector2d(width, height)
        property color uAccent: "{accent}"
        fragmentShader: Qt.resolvedUrl("shaders/splash_horizon.frag.qsb")
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.stage >= 1 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }

        // Canonical Wabi Sabi Black Hole logo centered dead-center inside the concentric astrolabe rings
        Image {
            id: brandMark
            width: Math.min(126, Kirigami.Units.gridUnit * 7)
            height: width
            x: Math.round((parent.width - width) * 0.5)
            y: Math.round(parent.height * 0.45 - height * 0.5)
            source: "images/wabi-sabi.svg"
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Clean hairline progress bar positioned strictly below the outer astrolabe ring
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.45 + 148)
            width: Kirigami.Units.gridUnit * 10
            height: 3
            radius: 1.5
            color: "{elevated}"
            clip: true

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "{accent}"
                width: parent.width * Math.min(1, Math.max(0.14, root.stage / 6))
                Behavior on width {
                    NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
"""


def build_plasmoids(output_root: Path, palette: dict[str, str]) -> None:
    """Materialize all five native KDE Plasma 6 Plasmoids under output_root/plasmoids."""
    base = output_root / "plasmoids"

    lnch = base / "org.tonantzintla.launcher"
    _write_json(lnch / "metadata.json", {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "Application Launchers",
            "Description": "Event Horizon unified constellation application launcher for Tonantzintla",
            "Icon": "tonantzintla-mark",
            "Id": "org.tonantzintla.launcher",
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Launcher",
            "Version": "1.2.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
        "X-Plasma-Provides": ["org.kde.plasma.launchermenu"],
    })
    _write_text(lnch / "contents/ui/main.qml", LAUNCHER_QML)

    ws = base / "org.tonantzintla.workspaces"
    _write_json(ws / "metadata.json", {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "Windows and Tasks",
            "Description": "Minimal virtual desktop pill indicator and wheel switcher for Tonantzintla",
            "Icon": "preferences-desktop-virtual",
            "Id": "org.tonantzintla.workspaces",
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Workspaces",
            "Version": "1.2.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    })
    _write_text(ws / "contents/ui/main.qml", WORKSPACES_QML)

    med = base / "org.tonantzintla.media"
    _write_json(med / "metadata.json", {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "Multimedia",
            "Description": "Spinning vinyl disc and acoustic waveform media deck for Tonantzintla",
            "Icon": "media-playback-start",
            "Id": "org.tonantzintla.media",
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Media",
            "Version": "1.2.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    })
    _write_text(med / "contents/ui/main.qml", MEDIA_QML)

    clk = base / "org.tonantzintla.clock"
    _write_json(clk / "metadata.json", {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "Date and Time",
            "Description": "Scalloped analog clock, live lunar disc, and calendar for Tonantzintla",
            "Icon": "clock",
            "Id": "org.tonantzintla.clock",
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Clock",
            "Version": "1.2.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    })
    _write_text(clk / "contents/ui/main.qml", CLOCK_QML)

    st = base / "org.tonantzintla.status"
    _write_json(st / "metadata.json", {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "System Information",
            "Description": "Inverted audio and battery status pills with tactile slider popup",
            "Icon": "audio-volume-high",
            "Id": "org.tonantzintla.status",
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Status",
            "Version": "1.2.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    })
    _write_text(st / "contents/ui/main.qml", STATUS_QML)


def render_splash_qml(palette: dict[str, str]) -> str:
    return (
        SPLASH_QML
        .replace("{void_}", palette["void_"])
        .replace("{elevated}", palette["elevated"])
        .replace("{accent}", palette["accent"])
        .replace("{foreground}", palette["foreground"])
    )
