pragma Singleton

import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Io
import ".."
import "NotificationModel.js" as Model

QtObject {
    id: root

    property var records: []
    property int nextUid: 0
    readonly property int unreadCount: records.filter(function(record) { return !record.read; }).length
    property var liveNotifications: ({})
    property ListModel history: ListModel {}
    property ListModel popups: ListModel {}
    property double now: Date.now()
    property bool soundAvailable: false
    property string soundState: "unchecked"
    property string soundStatus: "Choose a local WAV and check support. Sound is off by default."
    readonly property bool soundBusy: soundProcess.running
    property double lastSoundAt: 0
    property string soundRequestPath: ""
    property string soundOperation: "check"

    function checkSound() { startSound("check"); }
    function startSound(operation) {
        if (soundProcess.running) return;
        soundRequestPath=Settings.notificationSoundPath;
        soundOperation=operation;
        soundState=operation === "play" ? "playing" : "checking";
        soundStatus=operation === "play" ? "Playing notification sound…" : "Checking local sound and pw-play…";
        soundProcess.command=["python3",Environment.script("notification-sound.py"),operation,soundRequestPath,String(Settings.notificationSoundVolume)];
        soundProcess.running=true;
    }
    function playSound() {
        if (!Settings.notificationSoundsEnabled || Settings.doNotDisturb || soundProcess.running) return;
        const current=Date.now();
        if (current-lastSoundAt<2000) return;
        lastSoundAt=current;
        startSound("play");
    }
    property Connections soundSettings: Connections {
        target: Settings
        function onNotificationSoundPathChanged() {
            root.soundAvailable=false;
            root.soundState="unchecked";
            root.soundStatus="Sound selection changed; check support for the new file.";
        }
        function onNotificationSoundsEnabledChanged() {
            if (!Settings.notificationSoundsEnabled && root.soundOperation === "play" && soundProcess.running) {
                soundProcess.running=false;
                root.soundState="disabled";
                root.soundStatus="Notification sound disabled.";
            }
        }
    }
    property Process soundProcess: Process {
        id: soundProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.soundRequestPath !== Settings.notificationSoundPath
                        || (root.soundOperation === "play" && !Settings.notificationSoundsEnabled)) return;
                try {
                    const result=JSON.parse(text);
                    root.soundAvailable=result.available === true;
                    root.soundState=String(result.state || "error");
                    root.soundStatus=String(result.message || "Sound check failed.");
                } catch (_) {
                    root.soundAvailable=false;root.soundState="error";root.soundStatus="Sound helper did not return a valid result.";
                }
            }
        }
        onExited: function(code,status) {
            if (code !== 0 && (root.soundOperation !== "play" || Settings.notificationSoundsEnabled)) {
                root.soundAvailable=false;root.soundState="error";root.soundStatus="Sound helper failed to run.";
            }
        }
    }


    function notificationFor(uid) {
        return liveNotifications[uid] || null;
    }

    function containsUid(row, uid) {
        const members = row.uids || [];
        for (let index = 0; index < members.length; index++) {
            if (Number(members[index]) === Number(uid))
                return true;
        }
        return Number(row.uid) === Number(uid);
    }

    function insertOrFuse(model, entry, fuseWindow) {
        root.now = entry.receivedAt;
        for (let index = 0; index < model.count; index++) {
            const previous = model.get(index);
            if (!entry.critical && !previous.critical
                    && previous.groupKey === entry.groupKey
                    && entry.receivedAt - Number(previous.receivedAt) <= fuseWindow) {
                const members = [];
                const previousMembers = previous.uids || [previous.uid];
                for (let member = 0; member < previousMembers.length; member++)
                    members.push(previousMembers[member]);
                members.push(entry.uid);
                entry.uids = members;
                entry.count = Number(previous.count || 1) + 1;
                model.set(index, entry);
                if (index > 0)
                    model.move(index, 0, 1);
                return;
            }
        }
        model.insert(0, entry);
    }

    function rebuildHistory() {
        history.clear();
        Model.groups(records).forEach(function(group) { history.append(group); });
    }

    function remember(entry) {
        const next = Model.append(records, entry, 100);
        const retained = next.map(function(r) { return r.uid; });
        records.forEach(function(old) {
            if (retained.indexOf(old.uid) < 0) {
                removePopup(old.uid);
                const notification = notificationFor(old.uid);
                if (notification) notification.dismiss();
                delete liveNotifications[old.uid];
            }
        });
        records = next;
        rebuildHistory();
    }

    function makeEntry(uid, appName, summary, body, icon, critical, urgency, actions) {
        const timestamp = Date.now();
        return {
            "read": ShellState.ephemerisVisible && ShellState.ephemerisTab === "notifications",
            "uid": uid,
            "uids": [uid],
            "groupKey": String(appName || "System").trim().toLowerCase(),
            "appName": appName || "System",
            "summary": summary || "Notification",
            "body": body || "",
            "icon": icon || "",
            "time": Qt.formatTime(new Date(timestamp), "HH:mm"),
            "receivedAt": timestamp,
            "critical": critical,
            "urgency": urgency,
            "count": 1,
            "actions": actions || []
        };
    }

    function receive(notification) {
        notification.tracked = true;
        const uid = ++nextUid;
        liveNotifications[uid] = notification;

        const actions = [];
        if (notification.actions) {
            for (let index = 0; index < notification.actions.length; index++) {
                const action = notification.actions[index];
                if (action.identifier !== "default") {
                    actions.push({
                        "identifier": action.identifier || "action-" + index,
                        "text": action.text || action.identifier || "OPEN"
                    });
                }
            }
        }

        const critical = notification.urgency === NotificationUrgency.Critical;
        const urgency = critical ? 2
            : notification.urgency === NotificationUrgency.Low ? 0 : 1;
        const entry = makeEntry(uid, notification.appName, notification.summary,
            notification.body, notification.image || notification.appIcon,
            critical, urgency, actions);

        entry.groupKey = String(notification.desktopEntry || notification.appName || "System").trim().toLowerCase();
        remember(entry);

        if (!Settings.doNotDisturb && (!ShellState.deepFocus || critical)) {
            insertOrFuse(popups, makeEntry(uid, notification.appName,
                notification.summary, notification.body,
                notification.image || notification.appIcon,
                critical, urgency, actions), 12000);
            playSound();
        }
    }

    function preview(summary, body) {
        const uid = ++nextUid;
        const entry = makeEntry(uid, "Tonantzintla",
            summary || "Transit link online",
            body || "This toast is local to the active Tonantzintla shell.",
            "", false, 1, []);
        remember(entry);
        if (!Settings.doNotDisturb && !ShellState.deepFocus)
            insertOrFuse(popups, makeEntry(uid, "Tonantzintla",
                summary || "Transit link online",
                body || "This toast is local to the active Tonantzintla shell.",
                "", false, 1, []), 12000);
    }

    function removePopup(uid) {
        for (let index = 0; index < popups.count; index++) {
            if (containsUid(popups.get(index), uid)) {
                popups.remove(index);
                return;
            }
        }
    }

    function removeMessage(uid) {
        const notification = notificationFor(uid);
        if (notification) notification.dismiss();
        delete liveNotifications[uid];
        records = Model.remove(records, [uid]);
        removePopup(uid);
        rebuildHistory();
    }

    function removeHistory(uid) {
        const group = Model.groups(records).find(function(r) { return r.uid === uid; });
        const members = group ? group.uids : [uid];
        members.forEach(function(id) {
            const notification = notificationFor(id);
            if (notification) notification.dismiss();
            delete liveNotifications[id];
            removePopup(id);
        });
        records = Model.remove(records, members);
        rebuildHistory();
    }

    function invokeDefault(uid) {
        const notification = notificationFor(uid);
        if (!notification || !notification.actions)
            return;
        for (let index = 0; index < notification.actions.length; index++) {
            if (notification.actions[index].identifier === "default") {
                notification.actions[index].invoke();
                break;
            }
        }
        removePopup(uid);
    }

    function invokeAction(uid, identifier) {
        const notification = notificationFor(uid);
        if (!notification || !notification.actions)
            return;
        for (let index = 0; index < notification.actions.length; index++) {
            if (notification.actions[index].identifier === identifier) {
                notification.actions[index].invoke();
                break;
            }
        }
        removePopup(uid);
    }

    function clearHistory() {
        Object.keys(liveNotifications).forEach(function(uid) {
            const notification = notificationFor(uid);
            if (notification) notification.dismiss();
        });
        records = [];
        history.clear();
        popups.clear();
        liveNotifications = ({});
    }

    function markRead() {
        records = records.map(function(record) { return Object.assign({}, record, {read: true}); });
        rebuildHistory();
    }

    property Timer ageClock: Timer {
        interval: 15000
        running: root.history.count > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: function(notification) { root.receive(notification); }
    }
}
