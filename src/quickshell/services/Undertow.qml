pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Optional web wallpapers through undertow (a separate project and process).
// Parallax is the interface: undertow is started headless, with no tray icon or
// picker of its own. Nothing here polls; the library is read when Parallax asks
// and after an action finishes. Without undertow on PATH every action is
// refused with a message and `available` stays false.
QtObject {
    id: root

    property bool probed: false
    property bool available: false
    property bool loading: false
    property bool daemonRunning: false
    // True once this shell has started the daemon, so it may also stop it.
    property bool startedHere: false
    property var wallpapers: []
    property string message: ""
    property bool messageError: false
    property var queue: []
    property var job: null
    readonly property bool busy: action.running || queue.length > 0
    readonly property bool active: Settings.wallpaperKind === "web" && Settings.undertowWallpaper.length > 0

    // Parallax library entries. The path is only an identity; it is never read as a file.
    readonly property var entries: wallpapers.map(function(wallpaper) {
        return { path: "undertow://" + wallpaper.id, preview: wallpaper.thumb || "", name: wallpaper.title,
            source: "Web", kind: "web", webId: wallpaper.id };
    })

    function find(id) {
        return wallpapers.find(function(wallpaper) { return wallpaper.id === id; }) || null;
    }
    function idFor(path) {
        const value = String(path || "");
        return value.indexOf("undertow://") === 0 ? value.substring(11) : "";
    }
    function say(text, failed) { message = text; messageError = !!failed; }

    function refresh() {
        if (!probed) { if (!probe.running) probe.running = true; return; }
        if (available && !lister.running) { loading = true; lister.running = true; }
    }
    function run(kind, args, detail) {
        if (probed && !available) { say("Web wallpapers need undertow, which is not installed.", true); return; }
        queue = queue.concat([{ kind: kind, args: args, detail: detail || "" }]);
        pump();   // held until the probe has answered
    }
    function pump() {
        if (!probed || action.running || !queue.length) return;
        job = queue[0];
        queue = queue.slice(1);
        // One merged stream, so the last line is the outcome whether it succeeded or not.
        action.command = ["sh", "-c", "exec undertow \"$@\" 2>&1", "undertow"].concat(job.args);
        actionCode = -1; actionText = null;
        action.running = true;
    }

    function apply(id) {
        if (!find(id) && wallpapers.length) { say("That web wallpaper is no longer installed.", true); return; }
        say("Starting " + (find(id) ? find(id).title : id) + "…", false);
        run("set", ["set", id, "--headless"], id);
    }
    function setValue(id, name, value) {
        // undertow changes settings on the wallpaper it is showing.
        if (active && Settings.undertowWallpaper === id) run("prop", ["prop", name, String(value)], id);
    }
    function add(spec) {
        const source = String(spec || "").trim();
        if (!source.length) return;
        say("Fetching " + source + "…", false);
        run("add", ["add", source], source);
    }
    function remove(id) { run("remove", ["remove", id], id); }

    // Another kind of wallpaper took over. Stop the daemon only if this shell
    // started it; one the user started themselves is merely hidden.
    function release() {
        if (!available || !daemonRunning) return;
        run("release", [startedHere ? "quit" : "pause"]);
    }

    // The exit status and the collected output arrive separately, in either order.
    property int actionCode: -1
    property var actionText: null
    function settleAction() {
        if (actionCode >= 0 && actionText !== null) finish(actionCode, actionText);
    }
    function finish(exitCode, output) {
        const done = job;
        job = null;
        const failed = exitCode !== 0;
        const text = output.trim().split("\n")[0].replace(/^undertow:\s*/, "");
        if (done.kind === "set") {
            if (failed) say(text || "The web wallpaper could not be started.", true);
            else {
                if (output.indexOf("started undertow") >= 0) startedHere = true;
                daemonRunning = true;
                if (Environment.hasMpvpaper && !Environment.stopVideoProcess.running) Environment.stopVideoProcess.running = true;
                Settings.undertowWallpaper = done.detail;
                Settings.wallpaperKind = "web";
                say("Web wallpaper running.", false);
                settle.restart();   // its thumbnail is written a few seconds after it loads
            }
        } else if (done.kind === "release") {
            daemonRunning = false;
            if (!messageError) say("", false);
            if (!failed && startedHere) startedHere = false;
        } else if (done.kind === "add" || done.kind === "remove") {
            say(text || (failed ? "That did not work." : "Done."), failed);
            refresh();
        } else if (done.kind === "prop" && failed) {
            say(text || "That setting could not be changed.", true);
        }
        pump();
    }

    property Process probe: Process {
        command: ["sh", "-c", "command -v undertow >/dev/null 2>&1"]
        onExited: function(exitCode) {
            root.probed = true;
            root.available = exitCode === 0;
            if (root.available) { root.refresh(); root.pump(); }
            else if (root.queue.length) { root.queue = []; root.say("Web wallpapers need undertow, which is not installed.", true); }
        }
    }
    property Process lister: Process {
        command: ["undertow", "list", "--json"]
        stdout: StdioCollector { onStreamFinished: root.readListing(text) }
        onExited: function(exitCode) {
            root.loading = false;
            if (exitCode !== 0) root.say("undertow could not list its wallpapers.", true);
        }
    }
    function readListing(text) {
        if (!text.trim().length) return;
        try {
            const data = JSON.parse(text);
            wallpapers = data.wallpapers || [];
            daemonRunning = !!data.running;
        } catch (error) {
            say("undertow returned a library this version cannot read.", true);
            return;
        }
        // First listing after start: bring back the web wallpaper that was in use.
        const resume = active && !daemonRunning && !restored;
        restored = true;
        if (resume) apply(Settings.undertowWallpaper);
    }
    property bool restored: false
    property Process action: Process {
        stdout: StdioCollector { onStreamFinished: { root.actionText = text; root.settleAction(); } }
        onExited: function(exitCode) { root.actionCode = Math.max(0, exitCode); root.settleAction(); }
    }
    property Timer settle: Timer { interval: 6000; onTriggered: root.refresh() }

    property Connections kindWatch: Connections {
        target: Settings
        function onWallpaperKindChanged() { if (Settings.wallpaperKind !== "web") root.release(); }
    }
    Component.onCompleted: probe.running = true
}
