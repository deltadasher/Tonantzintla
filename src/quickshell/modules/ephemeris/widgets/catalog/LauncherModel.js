.pragma library

function stableHash(value) {
    let hash = 2166136261;
    const text = String(value || "");
    for (let index = 0; index < text.length; index++) {
        hash ^= text.charCodeAt(index);
        hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
}

function applications(values) {
    const seen = Object.create(null);
    return values.filter(function(app) {
        const name = String(app.name || "").trim();
        const id = String(app.id || name);
        if (!name || !String(app.command || "").trim() || /^about(?:\s|$)/i.test(name) || seen[id])
            return false;
        seen[id] = true;
        return true;
    }).sort(function(first, second) {
        const difference = stableHash(first.id || first.name) - stableHash(second.id || second.name);
        return difference || String(first.name).localeCompare(String(second.name));
    }).map(function(app) {
        return { id: "app:" + (app.id || app.name), appId: app.id || app.name,
            kind: "app", name: app.name, detail: app.genericName || app.comment || app.id || "Application",
            keywords: [app.name, app.genericName, app.comment, app.id].join(" "), app: app,
            enabled: true };
    });
}

function surfaceCommands(widgets) {
    const aliases = { walls: "wallpaper wallpapers parallax background library", calendar: "calendar weather forecast sundial earth helio",
        media: "resonance music lyrics equalizer pitch pitcher", audio: "volume microphone output mixer pipewire routing",
        network: "wifi wi-fi bluetooth ethernet", battery: "battery power energy", system: "cpu memory temperature system monitor",
        guide: "manual help keyboard bindings shortcuts", capture: "screenshot recording optics", notifications: "alerts history",
        focus: "focus concentration", workspaces: "windows workspace overview", clipboard: "copy paste history" };
    return widgets.filter(function(widget) { return widget.id !== "apps"; }).map(function(widget) {
        return { id: "surface:" + widget.id, kind: "surface", target: widget.id,
            name: widget.title, detail: "Open " + (widget.title || widget.id),
            keywords: [widget.id, widget.title, aliases[widget.id] || ""].join(" "), enabled: true };
    });
}

function searchText(value) {
    return String(value || "").toLowerCase().replace(/\s+/g, " ").trim();
}

function wordPrefixes(text, query) {
    const words = text.split(/[\s._\-/]+/);
    return query.split(" ").every(function(part) {
        return words.some(function(word) { return word.indexOf(part) === 0; });
    });
}

function nameScore(entry, needle) {
    const name = searchText(entry.name);
    if (name === needle) return 0;
    if (name.indexOf(needle) === 0) return 1;
    if (wordPrefixes(name, needle)) return 2;
    if (needle.length >= 3 && name.indexOf(needle) >= 0) return 3;
    return -1;
}

function matches(entry, needle) {
    needle = searchText(needle);
    if (nameScore(entry, needle) >= 0) return true;
    // Metadata is a fallback, not a bag of scattered matching letters.
    return needle.length >= 3 && wordPrefixes(searchText(
        [entry.detail, entry.keywords || ""].join(" ")), needle);
}

function astronomicalFact(needle) {
    const facts = {
        "c": { name: "Speed of Light (c)", value: "299,792,458 m/s", detail: "Universal physical constant in vacuum" },
        "speed of light": { name: "Speed of Light (c)", value: "299,792,458 m/s", detail: "Universal physical constant in vacuum" },
        "au": { name: "Astronomical Unit (1 AU)", value: "149,597,870,700 m", detail: "~149.6 million km · mean Earth-Sun distance" },
        "astronomical unit": { name: "Astronomical Unit (1 AU)", value: "149,597,870,700 m", detail: "~149.6 million km · mean Earth-Sun distance" },
        "ly": { name: "Light Year (1 ly)", value: "9.4607 × 10¹² km", detail: "Distance traversed by light in one Julian year" },
        "light year": { name: "Light Year (1 ly)", value: "9.4607 × 10¹² km", detail: "Distance traversed by light in one Julian year" },
        "parsec": { name: "Parsec (1 pc)", value: "3.0857 × 10¹³ km", detail: "~3.2616 light years · parallax of one arcsecond" },
        "solar mass": { name: "Solar Mass (M☉)", value: "1.9884 × 10³⁰ kg", detail: "~333,000 Earth masses" },
        "earth radius": { name: "Earth Radius (R⊕)", value: "6,371 km", detail: "Mean volumetric radius of Earth" },
        "moon distance": { name: "Moon Distance", value: "384,400 km", detail: "Semi-major axis of the Moon's orbit" }
    };
    const key = needle.trim().toLowerCase();
    if (facts[key]) {
        const item = facts[key];
        return {
            id: "astro:" + key,
            kind: "astro",
            name: item.name + " = " + item.value,
            detail: item.detail,
            result: item.value,
            enabled: true
        };
    }
    return null;
}

// Bounded recursive-descent calculator. Input is data; never JavaScript source.
function calculate(expression, degrees, answer) {
    try {
        const input=String(expression || "").trim();
        if(!input || input.length>256) throw new Error("Use an expression of 1–256 characters.");
        const tokens=[]; let at=0;
        while(at<input.length) {
            const rest=input.slice(at), match=rest.match(/^(?:\s+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|[a-zA-Z]+|[+*/%()^!,\-])/);
            if(!match) throw new Error("Unsupported character.");
            at+=match[0].length;
            if(match[0].trim()) tokens.push(match[0]);
            if(tokens.length>192) throw new Error("Expression is too complex.");
        }
        let pos=0,depth=0;
        function peek() { return tokens[pos] || ""; }
        function take(value) { if(peek()===value) { pos++; return true; } return false; }
        function finite(n) { if(!isFinite(n)) throw new Error("Result is outside the real finite range."); return n; }
        function expr() {
            let value=product();
            while(peek()==="+" || peek()==="-") { const op=tokens[pos++],right=product();value=finite(op==="+"?value+right:value-right); }
            return value;
        }
        function product() {
            let value=unary();
            while(["*","/","%"].indexOf(peek())>=0) { const op=tokens[pos++],right=unary();value=finite(op==="*"?value*right:op==="/"?value/right:value%right); }
            return value;
        }
        function unary() {
            if(++depth>32) throw new Error("Use fewer nested operations.");
            const value=take("+")?unary():take("-")?-unary():power(); depth--; return value;
        }
        function power() {
            let value=primary();
            while(take("!")) { if(value<0 || value>170 || Math.floor(value)!==value) throw new Error("Factorial requires a whole number from 0 to 170."); let n=1;for(let i=2;i<=value;i++) n*=i;value=n; }
            if(take("^")) value=finite(Math.pow(value,unary()));
            return value;
        }
        function primary() {
            if(take("(")) { const value=expr();if(!take(")")) throw new Error("Close the parentheses.");return value; }
            const token=tokens[pos++];
            if(!token) throw new Error("Complete the expression.");
            if(/^(?:\d|\.)/.test(token)) return finite(Number(token));
            const name=token.toLowerCase();
            if(name==="pi") return Math.PI;
            if(name==="e") return Math.E;
            if(name==="ans") return finite(Number(answer || 0));
            if(!take("(")) throw new Error("Unknown number or function.");
            const args=[expr()];
            while(take(",")) { if(args.length>=8) throw new Error("Use at most eight arguments.");args.push(expr()); }
            if(!take(")")) throw new Error("Close the function parentheses.");
            if(name==="min" || name==="max") return Math[name].apply(Math,args);
            if(args.length!==1) throw new Error("This function takes one argument.");
            const x=args[0],angle=degrees?x*Math.PI/180:x;
            if(name==="sin") return finite(Math.sin(angle));
            if(name==="cos") return finite(Math.cos(angle));
            if(name==="tan") return finite(Math.tan(angle));
            if(["asin","acos","atan"].indexOf(name)>=0) return finite(Math[name](x)*(degrees?180/Math.PI:1));
            if(name==="ln") return finite(Math.log(x));
            if(name==="log") return finite(Math.log(x)/Math.LN10);
            if(["sqrt","abs","exp","floor","ceil","round"].indexOf(name)>=0) return finite(Math[name](x));
            throw new Error("Unknown function: "+name);
        }
        const value=finite(expr());
        if(pos!==tokens.length) throw new Error("Unexpected token: "+peek());
        return {ok:true,value:value,text:String(Number(value.toPrecision(12))),error:""};
    } catch(error) { return {ok:false,value:0,text:"",error:String(error.message || error)}; }
}
function evaluateMath(needle) {
    const trimmed=String(needle || "").trim();
    if(!/[0-9]/.test(trimmed) || !/[+*/%^()\-]/.test(trimmed)) return null;
    const result=calculate(trimmed,false,0);
    if(!result.ok) return null;
    return {id:"calc:"+trimmed,kind:"calc",name:"= "+result.text,
        detail:trimmed+" · press Enter to copy",result:result.text,enabled:true};
}

function terminalCommand(query) {
    const trimmed = String(query || "").trim();
    if (trimmed.startsWith("!") || trimmed.startsWith("$ ")) {
        const cmd = trimmed.replace(/^[!\$]\s*/, "").trim();
        if (cmd.length > 0) {
            return {
                id: "cmd:" + cmd,
                kind: "terminal_cmd",
                name: "Run in terminal: " + cmd,
                detail: "Execute in configured terminal emulator",
                cmd: cmd,
                enabled: true
            };
        }
    }
    return null;
}

function filter(entries, query, category, favorites, enableCalc) {
    let needle = searchText(query);
    const commandsOnly = needle.charAt(0) === ">";
    if (commandsOnly)
        needle = needle.substring(1).trim();
    const saved = favorites || [];
    const eligible = entries.filter(function(entry) {
        if (commandsOnly ? entry.kind === "app"
            : category === "apps" ? entry.kind !== "app"
            : category === "actions" ? entry.kind === "app"
            : category === "saved" ? entry.kind !== "app" || saved.indexOf(entry.appId) < 0 : false)
            return false;
        return true;
    });
    // Keep the discovery order for empty searches and equal-strength matches.
    // Once a name matches, unrelated metadata hits cannot crowd it out.
    const named = needle ? eligible.map(function(entry, index) {
        return {entry: entry, index: index, score: nameScore(entry, needle)};
    }).filter(function(item) { return item.score >= 0; }) : [];
    named.sort(function(a, b) { return a.score - b.score || a.index - b.index; });
    const matched = !needle ? eligible : named.length
        ? named.map(function(item) { return item.entry; })
        : eligible.filter(function(entry) { return matches(entry, needle); });

    if (!commandsOnly && category !== "saved" && needle) {
        const special = [];
        const cmd = terminalCommand(query);
        if (cmd) special.push(cmd);
        if (enableCalc !== false) {
            const math = evaluateMath(needle);
            if (math) special.push(math);
            const astro = !named.length && needle.length > 2 ? astronomicalFact(needle) : null;
            if (astro) special.push(astro);
        }
        if (special.length > 0)
            return special.concat(matched);
    }

    return matched;
}

function selectedId(entries, currentId) {
    if (entries.some(function(entry) { return entry.id === currentId; }))
        return currentId;
    const available = entries.find(function(entry) { return entry.enabled !== false; });
    return available ? available.id : (entries.length ? entries[0].id : "");
}

function moveSelection(entries, currentId, delta) {
    if (!entries.length)
        return "";
    let index = entries.findIndex(function(entry) { return entry.id === currentId; });
    if (index < 0)
        index = delta > 0 ? -1 : 0;
    return entries[(index + delta + entries.length) % entries.length].id;
}
