const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const units = vm.createContext({});
const path = 'src/quickshell/components/UnitConversion.js';
if (fs.existsSync(path)) vm.runInContext(fs.readFileSync(path, 'utf8').replace('.pragma library', ''), units);
function convert(query) {
    assert.equal(typeof units.convert, 'function', 'shared offline converter exists');
    return units.convert(query);
}
function near(query, expected, label) {
    const result = convert(query);
    assert.ok(result && result.ok, query);
    assert.ok(Math.abs(result.value - expected) <= Math.max(1, Math.abs(expected)) * 1e-10, query + ': ' + result.value);
    assert.equal(result.unit, label);
    assert.ok(result.text.endsWith(' ' + label));
}
test('length and mass accept signed decimals, attached units and full names', () => {
    near('2.5km to meters', 2500, 'm');
    near('-12 inches in cm', -30.48, 'cm');
    near('.5 nautical miles to m', 926, 'm');
    near('1e3 milligrams -> grams', 1, 'g');
    near('2 pounds to kg', 0.90718474, 'kg');
    near('1 metric ton to kg', 1000, 'kg');
});
test('temperature conversions use offsets in both directions', () => {
    near('32 F to C', 0, '°C');
    near('-40 degrees Celsius to degrees Fahrenheit', -40, '°F');
    near('273.15 kelvin in celsius', 0, '°C');
    near('0 °C to K', 273.15, 'K');
});
test('volume and speed preserve multiword units and US versus imperial volume', () => {
    near('1 gallon to liters', 3.785411784, 'L');
    near('1 imperial gallon to liters', 4.54609, 'L');
    near('2 tablespoons to ml', 29.5735295625, 'mL');
    near('36 kilometers per hour to meters per second', 10, 'm/s');
    near('60 mph to km/h', 96.56064, 'km/h');
});
test('data distinguishes decimal and binary prefixes as well as byte and bit symbols', () => {
    near('1 MB to Mb', 8, 'Mb');
    near('1 GB to MB', 1000, 'MB');
    near('1 GiB to MiB', 1024, 'MiB');
    near('1 MiB to bytes', 1048576, 'B');
    near('8 bits to B', 1, 'B');
    near('1 kibibyte to b', 8192, 'b');
});
test('ordinary search and arithmetic remain outside conversion parsing', () => {
    for (const query of ['firefox', 'speed of light', 'm to km', '1+2', 'sqrt(81)', '2 km', '']) assert.equal(convert(query), null, query);
});
test('invalid conversions produce useful errors and cannot execute input', () => {
    for (const query of ['1 kg to km', '10 USD to EUR', '10 cm to banana', '1e309 m to cm', '1e308 km to mm', '-1 K to C', '1 m to ' + 'x'.repeat(300)]) {
        const result = convert(query);
        assert.ok(result && !result.ok, query);
        assert.ok(result.error.length > 0, query);
        assert.equal(result.text, '');
    }
    for (const query of ['1 m to constructor', '1 m to __proto__', '1 m to this.constructor()', '1 m to km;process.exit()']) {
        assert.equal(convert(query).ok, false, query);
    }
});
test('display rounding does not discard precision needed by calculator ans', () => {
    const result = convert('1 m to ft');
    assert.ok(Math.abs(result.value - 3.280839895013123) < 1e-14);
    assert.equal(result.text, '3.28083989501 ft');
});
