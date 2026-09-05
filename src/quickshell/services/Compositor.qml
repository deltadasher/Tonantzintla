pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Stable compositor API for the shell. The 1.0 backend uses Niri's
// newline-delimited JSON event stream and short-lived action sockets.
QtObject {
    id: root

    property var workspaces: []
    property var windows: []
    property int focusedWindowId: -1
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")
    readonly property bool available: socketPath.length > 0
    readonly property string focusedOutput: {
        const focused = workspaces.find(function(workspace) {
            return workspace.is_focused === true;
        });
        return focused && focused.output ? focused.output : "";
    }

    function focusWorkspace(id) {
        actionSocket.queue("{\"Action\":{\"FocusWorkspace\":{\"reference\":{\"Id\":" + id + "}}}}");
    }

    function focusWindow(id) {
        actionSocket.queue("{\"Action\":{\"FocusWindow\":{\"id\":" + id + "}}}");
    }

    function upsertWindow(win) {
        let found = false;
        const next = windows.map(function(candidate) {
            if (candidate.id === win.id) {
                found = true;
                return win;
            }
            return candidate;
        });
        if (!found)
            next.push(win);
        windows = next;
    }

    property Socket eventSocket: Socket {
        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (connected)
                write("\"EventStream\"\n");
        }

        parser: SplitParser {
            onRead: function(line) {
                if (!line)
                    return;

                let message;
                try {
                    message = JSON.parse(line);
                } catch (error) {
                    console.warn("[Tonantzintla/Compositor] Invalid event:", error);
                    return;
                }

                if (message.WorkspacesChanged !== undefined) {
                    root.workspaces = message.WorkspacesChanged.workspaces || [];
                    return;
                }

                if (message.WorkspaceActivated !== undefined) {
                    const event = message.WorkspaceActivated;
                    const target = root.workspaces.find(function(workspace) {
                        return workspace.id === event.id;
                    });
                    root.workspaces = root.workspaces.map(function(workspace) {
                        const sameOutput = target && workspace.output === target.output;
                        return Object.assign({}, workspace, {
                            is_active: workspace.id === event.id ? true
                                : sameOutput ? false : workspace.is_active,
                            is_focused: workspace.id === event.id && event.focused === true
                        });
                    });
                    return;
                }

                if (message.WindowsChanged !== undefined) {
                    root.windows = message.WindowsChanged.windows || [];
                    const focused = root.windows.find(function(window) {
                        return window.is_focused;
                    });
                    root.focusedWindowId = focused ? focused.id : -1;
                    return;
                }

                if (message.WindowOpenedOrChanged !== undefined
                        && message.WindowOpenedOrChanged.window) {
                    const window = message.WindowOpenedOrChanged.window;
                    root.upsertWindow(window);
                    if (window.is_focused)
                        root.focusedWindowId = window.id;
                    return;
                }

                if (message.WindowClosed !== undefined) {
                    const closedId = message.WindowClosed.id;
                    root.windows = root.windows.filter(function(window) {
                        return window.id !== closedId;
                    });
                    if (root.focusedWindowId === closedId)
                        root.focusedWindowId = -1;
                    return;
                }

                if (message.WindowFocusChanged !== undefined) {
                    const id = message.WindowFocusChanged.id === null
                        || message.WindowFocusChanged.id === undefined
                        ? -1 : message.WindowFocusChanged.id;
                    root.focusedWindowId = id;
                    root.windows = root.windows.map(function(window) {
                        return Object.assign({}, window, { is_focused: window.id === id });
                    });
                }
            }
        }
    }

    property Socket actionSocket: Socket {
        id: actionSocket
        path: root.socketPath
        property var queueItems: []

        function queue(json) {
            queueItems.push(json);
            if (connected)
                flush();
            else
                connected = true;
        }

        function flush() {
            while (queueItems.length > 0)
                write(queueItems.shift() + "\n");
        }

        onConnectedChanged: {
            if (connected)
                flush();
        }

        parser: SplitParser {
            onRead: function() { actionSocket.connected = false; }
        }
    }
}
