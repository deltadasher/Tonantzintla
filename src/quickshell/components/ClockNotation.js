.pragma library
// Hosts retain their existing minute clock; formatting never acquires time.
function hour(date, twelve) {
    const value = date.getHours();
    return twelve ? String(value % 12 || 12) : String(value).padStart(2, "0");
}
function period(date, twelve) { return twelve ? (date.getHours() < 12 ? "am" : "pm") : ""; }
function stacked(date, twelve) { return hour(date, twelve) + "\n" + String(date.getMinutes()).padStart(2, "0"); }
function time(date, twelve) {
    return stacked(date, twelve).replace("\n", ":") + (twelve ? " " + period(date, twelve) : "");
}
