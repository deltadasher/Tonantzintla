.pragma library

function seconds(minutes, second) {
    const value = Number(second);
    return value >= 0 && value < 60 ? Number(minutes) * 60 + value : -1;
}

function syncedLines(text) {
    const parsed = [];
    String(text || "").slice(0, 262144).split(/\r?\n/).forEach(function(line) {
        const times = [];
        const tags = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        let match;
        while ((match = tags.exec(line)) !== null) {
            const time = seconds(match[1], match[2]);
            if (time >= 0) times.push(time);
        }
        if (!times.length) return;
        const content = line.replace(/\[\d+:\d+(?:\.\d+)?\]/g, "").trim();
        const tokens = [];
        const wordTags = /<(\d+):(\d+(?:\.\d+)?)>/g;
        while ((match = wordTags.exec(content)) !== null)
            tokens.push({time: seconds(match[1], match[2]), start: match.index, end: wordTags.lastIndex});
        let valid = times.length === 1 && tokens.length > 0;
        const words = tokens.map(function(token, index) {
            if (token.time < times[0] || (index > 0 && token.time < tokens[index - 1].time)) valid = false;
            return {time: token.time, text: content.slice(token.end, index + 1 < tokens.length ? tokens[index + 1].start : content.length)};
        });
        const plain = content.replace(/<\d+:\d+(?:\.\d+)?>/g, "").trim() || "···";
        times.forEach(function(time) { parsed.push({time: time, text: plain, words: valid ? words.filter(function(word) { return word.text.length > 0; }) : []}); });
    });
    parsed.sort(function(left, right) { return left.time - right.time; });
    return parsed;
}

function escapeHtml(text) {
    return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function wordHtml(line, position) {
    const words = line.words || [];
    if (!words.length) return escapeHtml(line.text);
    return words.map(function(word, index) {
        const current = position >= word.time && (index + 1 === words.length || position < words[index + 1].time);
        const escaped = escapeHtml(word.text);
        return '<a href="seek:' + word.time + '" style="text-decoration:none">'
            + (current ? '<strong>' + escaped + '</strong>' : escaped) + '</a>';
    }).join("");
}
