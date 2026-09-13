pragma Singleton

import QtQuick
import Quickshell.Services.Notifications
import ".."

QtObject {
    id: root

    property int nextUid: 0
    property int unreadCount: 0
    property var liveNotifications: ({})
    property ListModel history: ListModel {}
    property ListModel popups: ListModel {}
    property double now: Date.now()

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

    function makeEntry(uid, appName, summary, body, icon, critical, urgency, actions) {
        const timestamp = Date.now();
        return {
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

        insertOrFuse(history, entry, 180000);
        while (history.count > 100)
            history.remove(history.count - 1);
        unreadCount++;

        if (!Settings.doNotDisturb && (!ShellState.deepFocus || critical))
            insertOrFuse(popups, makeEntry(uid, notification.appName,
                notification.summary, notification.body,
                notification.image || notification.appIcon,
                critical, urgency, actions), 12000);
    }

    function preview(summary, body) {
        const uid = ++nextUid;
        const entry = makeEntry(uid, "Tonantzintla",
            summary || "Transit link online",
            body || "This toast is local to the active Tonantzintla shell.",
            "", false, 1, []);
        insertOrFuse(history, entry, 180000);
        unreadCount++;
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

    function removeHistory(uid) {
        for (let index = 0; index < history.count; index++) {
            if (containsUid(history.get(index), uid)) {
                const row = history.get(index);
                history.remove(index);
                const members = row.uids || [row.uid];
                for (let member = 0; member < members.length; member++) {
                    const groupedNotification = notificationFor(members[member]);
                    if (groupedNotification)
                        groupedNotification.dismiss();
                    delete liveNotifications[members[member]];
                }
                break;
            }
        }
        removePopup(uid);
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
        history.clear();
        popups.clear();
        liveNotifications = ({});
        unreadCount = 0;
    }

    function markRead() {
        unreadCount = 0;
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
