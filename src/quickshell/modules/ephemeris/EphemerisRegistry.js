.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function getLayout(name, screenWidth, screenHeight, topClearance) {
    const margin = 16;
    const usableTop = Math.max(margin, topClearance || 72);
    const usableHeight = Math.max(360, screenHeight - usableTop - margin);
    let width = 780;
    let height = 640;
    let placement = "center";
    let title = "Ephemeris";
    let code = "EPH/00";

    if (name === "apps") {
        width = Math.min(520, screenWidth - margin * 2);
        height = usableHeight; placement = "left";
        title = "Application catalog"; code = "EPH/APP";
    } else if (name === "tools") {
        width = 900; height = Math.min(860, usableHeight); title = "Field tools"; code = "EPH/FLD";
    } else if (name === "walls") {
        width = screenWidth;
        height = screenHeight;
        placement = "horizon";
        title = "Parallax orbit"; code = "EPH/WAL";
    } else if (name === "clipboard") {
        width = 820; height = 670; title = "Clipboard orbit"; code = "EPH/CLP";
    } else if (name === "notifications") {
        width = 470; height = Math.min(760, usableHeight); placement = "right";
        title = "Transit signals"; code = "EPH/SIG";
    } else if (name === "settings") {
        width = Math.min(1050, screenWidth - margin * 2); height = Math.min(720, usableHeight);
        title = "Observatory settings"; code = "EPH/CFG";
    } else if (name === "calendar") {
        width = Math.min(1480, screenWidth - margin * 2); height = Math.min(680, usableHeight);
        title = "Celestial calendar"; code = "EPH/CAL";
    } else if (name === "capture") {
        width = Math.min(1080, screenWidth - margin * 2); height = Math.min(650, usableHeight);
        title = "Optics bay"; code = "EPH/OPT";
    } else if (name === "media") {
        width = Math.min(1040, screenWidth - margin * 2);
        height = Math.min(680, usableHeight); placement = "left";
        title = "Resonance console"; code = "EPH/MPR";
    } else if (name === "network") {
        width = 820; height = Math.min(650, usableHeight); placement = "right";
        title = "Link array"; code = "EPH/NET";
    } else if (name === "audio") {
        width = 760; height = Math.min(650, usableHeight); placement = "right";
        title = "Acoustic array"; code = "EPH/AUD";
    } else if (name === "workspaces") {
        width = Math.min(1120, screenWidth - margin * 2); height = Math.min(690, usableHeight);
        title = "Parallax navigator"; code = "EPH/NIR";
    } else if (name === "battery") {
        width = Math.min(780, screenWidth - margin * 2); height = Math.min(590, usableHeight); placement = "right";
        title = "Reactor telemetry"; code = "EPH/PWR";
    } else if (name === "focus") {
        width = Math.min(900, screenWidth - margin * 2); height = Math.min(650, usableHeight);
        title = "Focus orbit"; code = "EPH/FCS";
    } else if (name === "system") {
        width = Math.min(1060, screenWidth - margin * 2); height = Math.min(660, usableHeight);
        title = "Observatory telemetry"; code = "EPH/SYS";
    } else if (name === "guide") {
        width = Math.min(720, screenWidth - margin * 2);
        height = usableHeight; placement = "left";
        title = "Tonantzintla flight manual"; code = "EPH/GDE";
    } else if (name === "timer") {
        width = 680; height = Math.min(610, usableHeight);
        title = "Chronos array"; code = "EPH/TMR";
    } else if (name === "quickstats") {
        width = 680; height = Math.min(620, usableHeight);
        title = "Local constellation"; code = "EPH/TEL";
    }

    width = clamp(width, 360, screenWidth - margin * 2);
    height = clamp(height, 320, usableHeight);

    let x = Math.round((screenWidth - width) / 2);
    let y = usableTop + Math.round((usableHeight - height) / 2);
    if (placement === "left") {
        x = margin;
        y = usableTop;
    } else if (placement === "right") {
        x = screenWidth - width - margin;
        y = usableTop;
    } else if (placement === "horizon") {
        x = margin;
        y = usableTop;
    }

    return { "name": name, "x": x, "y": y, "width": width, "height": height,
        "title": title, "code": code, "placement": placement };
}
