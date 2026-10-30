.pragma library

// Local scalar conversions only. Values are parsed as numbers, never executed.
// Length uses metres, mass kilograms, volume litres, speed m/s and data bits.
// Unqualified cooking measures are US customary; imperial measures are explicit.
var definitions = [
    ["length", "nm", 1e-9, "nanometer|nanometers|nanometre|nanometres"],
    ["length", "µm", 1e-6, "um|μm|micrometer|micrometers|micrometre|micrometres|micron|microns"],
    ["length", "mm", .001, "millimeter|millimeters|millimetre|millimetres"],
    ["length", "cm", .01, "centimeter|centimeters|centimetre|centimetres"],
    ["length", "m", 1, "meter|meters|metre|metres"],
    ["length", "km", 1000, "kilometer|kilometers|kilometre|kilometres"],
    ["length", "in", .0254, "inch|inches"],
    ["length", "ft", .3048, "foot|feet"],
    ["length", "yd", .9144, "yard|yards"],
    ["length", "mi", 1609.344, "mile|miles"],
    ["length", "nmi", 1852, "nautical mile|nautical miles"],
    ["mass", "mg", .000001, "milligram|milligrams"],
    ["mass", "g", .001, "gram|grams"],
    ["mass", "kg", 1, "kilogram|kilograms|kilo|kilos"],
    ["mass", "oz", .028349523125, "ounce|ounces"],
    ["mass", "lb", .45359237, "lbs|pound|pounds"],
    ["mass", "st", 6.35029318, "stone|stones"],
    ["mass", "t", 1000, "tonne|tonnes|metric ton|metric tons"],
    ["mass", "US ton", 907.18474, "short ton|short tons|us tons"],
    ["volume", "mL", .001, "milliliter|milliliters|millilitre|millilitres"],
    ["volume", "L", 1, "liter|liters|litre|litres"],
    ["volume", "tsp", .00492892159375, "teaspoon|teaspoons|us teaspoon|us teaspoons"],
    ["volume", "tbsp", .01478676478125, "tablespoon|tablespoons|us tablespoon|us tablespoons"],
    ["volume", "US fl oz", .0295735295625, "fl oz|fluid ounce|fluid ounces|us fluid ounce|us fluid ounces"],
    ["volume", "US cup", .2365882365, "cup|cups|us cups"],
    ["volume", "US pt", .473176473, "pt|pint|pints|us pint|us pints"],
    ["volume", "US qt", .946352946, "qt|quart|quarts|us quart|us quarts"],
    ["volume", "US gal", 3.785411784, "gal|gallon|gallons|us gallon|us gallons"],
    ["volume", "imp gal", 4.54609, "imperial gallon|imperial gallons|uk gallon|uk gallons"],
    ["volume", "imp pt", .56826125, "imperial pint|imperial pints|uk pint|uk pints"],
    ["speed", "m/s", 1, "mps|meter per second|meters per second|metre per second|metres per second"],
    ["speed", "km/h", 1/3.6, "kph|kmh|kilometer per hour|kilometers per hour|kilometre per hour|kilometres per hour"],
    ["speed", "mph", .44704, "mile per hour|miles per hour"],
    ["speed", "ft/s", .3048, "fps|foot per second|feet per second"],
    ["speed", "kn", 1852/3600, "kt|knot|knots"],
    ["temperature", "°C", 1, "c|celsius|degree celsius|degrees celsius", 273.15],
    ["temperature", "°F", 5/9, "f|fahrenheit|degree fahrenheit|degrees fahrenheit", 459.67],
    ["temperature", "K", 1, "kelvin|kelvins|degree kelvin|degrees kelvin", 0]
];

function normalized(value) { return String(value).trim().replace(/\s+/g, " "); }

function unit(input) {
    const raw = normalized(input);
    // Byte/bit symbols are intentionally case sensitive: MB and Mb differ by 8.
    const symbol = raw.match(/^([kKmMgGtTpP]?)(i?)([bB])$/);
    if (symbol && (!symbol[2] || symbol[1])) {
        const power = symbol[1] ? "kmgtp".indexOf(symbol[1].toLowerCase()) + 1 : 0;
        const factor = Math.pow(symbol[2] ? 1024 : 1000, power) * (symbol[3] === "B" ? 8 : 1);
        const label = (power ? symbol[1].toUpperCase() : "") + symbol[2] + symbol[3];
        return {family:"data", label:label, factor:factor, offset:0};
    }
    const key = raw.toLowerCase();
    const data = key.match(/^(?:(kilo|mega|giga|tera|peta|kibi|mebi|gibi|tebi|pebi))?(bit|byte)s?$/);
    if (data) {
        const prefixes = ["kilo", "mega", "giga", "tera", "peta", "kibi", "mebi", "gibi", "tebi", "pebi"];
        const index = data[1] ? prefixes.indexOf(data[1]) : -1;
        const power = index < 0 ? 0 : index % 5 + 1;
        return unit((power ? "KMGTP"[power-1] : "") + (index >= 5 ? "i" : "") + (data[2] === "byte" ? "B" : "b"));
    }
    for (let i=0; i<definitions.length; i++) {
        const row = definitions[i];
        if (row[1].toLowerCase() === key || row[3].split("|").indexOf(key) >= 0)
            return {family:row[0], label:row[1], factor:row[2], offset:row[4] || 0};
    }
    return null;
}

function failure(message) { return {ok:false, value:0, text:"", unit:"", error:message}; }

function convert(expression) {
    const input = normalized(expression).replace(/−/g, "-");
    if (input.length > 256) return failure("Use a conversion of at most 256 characters.");
    // Requiring a leading number and explicit separator avoids ordinary app searches.
    const match = input.match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*(.+?)(?:\s+(?:to|in)\s+|\s*(?:->|→)\s*)(.+)$/i);
    if (!match) return null;
    const from = unit(match[2]), to = unit(match[3]);
    if (!from || !to) return failure("Unknown unit. Try 5 km to mi, 72 F to C, or 1 GiB to MB.");
    if (from.family !== to.family) return failure("Cannot convert " + from.family + " to " + to.family + ". Choose units of the same type.");
    const amount = Number(match[1]);
    const base = (amount + from.offset) * from.factor;
    if (!isFinite(amount) || !isFinite(base)) return failure("Result is outside the finite range.");
    if (from.family === "temperature" && base < -1e-10) return failure("Temperature cannot be below absolute zero.");
    const value = base / to.factor - to.offset;
    if (!isFinite(value)) return failure("Result is outside the finite range.");
    const rounded = Number(value.toPrecision(12));
    return {ok:true, value:value, text:String(rounded) + " " + to.label, unit:to.label, error:""};
}
