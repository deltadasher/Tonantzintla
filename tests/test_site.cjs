const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync('docs/site.js', 'utf8');

function element(attrs = {}) {
    return {
        attrs, events: {}, dataset: {}, hidden: false, disabled: false,
        isConnected: true, textContent: '', focusCount: 0,
        classList: {values: new Set(), add(value) {this.values.add(value);}},
        addEventListener(type, handler) {this.events[type] = handler;},
        getAttribute(name) {return this.attrs[name];},
        setAttribute(name, value) {this.attrs[name] = value;},
        focus() {this.focusCount++;},
    };
}

function setup(options = {}) {
    const names = ['aperture', 'ephemeris', 'parallax', 'resonance', 'umbra'];
    const panels = options.empty ? [] : names.map(() => element());
    const tabs = options.empty ? [] : names.map((name, i) => element({
        'aria-controls': 'panel-' + name,
        'aria-selected': String(i === (options.selected ?? 0)),
    }));
    const watch = options.empty ? [] : [element(), element()];
    const close = element();
    const copy = options.empty ? null : element();
    const status = element();
    const code = element(); code.textContent = '  echo example\n';
    const mediaSource = element({src: 'assets/desktop-demo.mp4'});
    let playCount = 0, pauseCount = 0, copied, writes = 0, selected;
    const video = {
        play() {playCount++; return Promise.reject(Error('autoplay blocked'));},
        pause() {pauseCount++;},
    };
    const dialog = options.empty ? null : element();
    if (dialog) {
        dialog.open = false;
        dialog.showCount = 0;
        dialog.querySelector = selector => ({video, source: mediaSource, '[data-close-demo]': close}[selector]);
        dialog.showModal = () => {dialog.open = true; dialog.showCount++;};
        dialog.close = () => {dialog.open = false; dialog.events.close();};
        if (options.noModal) delete dialog.showModal;
    }
    const reveals = options.reveals ? [element(), element()] : [];
    const motion = element(); motion.matches = !!options.reduced;
    const window = {
        events: {},
        location: {hash: options.hash ?? '', assign(url) {this.assigned = url;}},
        addEventListener(type, handler) {this.events[type] = handler;},
        getSelection() {return options.nullSelection ? null : {
            removeAllRanges() {}, addRange(range) {selected = range.code;},
        };},
        matchMedia() {return motion;},
    };
    const observed = [], unobserved = [];
    let observerCallback, disconnected = false;
    if (options.observer) window.IntersectionObserver = class {
        constructor(callback, config) {observerCallback = callback; assert.equal(config.threshold, .08);}
        observe(target) {observed.push(target);}
        unobserve(target) {unobserved.push(target);}
        disconnect() {disconnected = true;}
    };
    const navigator = options.noClipboard ? {} : {clipboard: {writeText: async text => {
        writes++;
        if (options.denied) throw Error('clipboard denied');
        if (options.pending) await options.pending;
        copied = text;
    }}};
    const document = {
        querySelectorAll(selector) {return {'[data-instrument]': tabs, '[data-watch]': watch, '[data-reveal]': reveals}[selector] ?? [];},
        getElementById(id) {return panels[names.indexOf(id.replace('panel-', ''))];},
        querySelector(selector) {return {
            '#demo-dialog': dialog, '#copy-install': copy,
            '#install-commands': options.missingCode ? null : code, '#copy-status': status,
        }[selector] ?? null;},
        createRange() {return {selectNodeContents(target) {this.code = target;}};},
    };
    vm.runInNewContext(source, {document, navigator, window});
    return {tabs, panels, watch, close, dialog, copy, status, code, window, reveals, motion,
        observed, unobserved, observerCallback, disconnected: () => disconnected,
        copied: () => copied, writes: () => writes, selected: () => selected,
        playCount: () => playCount, pauseCount: () => pauseCount};
}

function expectSelected(site, index) {
    site.tabs.forEach((tab, i) => {
        assert.equal(tab.attrs['aria-selected'], String(i === index));
        assert.equal(tab.tabIndex, i === index ? 0 : -1);
        assert.equal(site.panels[i].hidden, i !== index);
    });
}
function press(site, index, key, expected) {
    let prevented = false;
    const before = site.tabs.map(tab => tab.focusCount);
    site.tabs[index].events.keydown({key, preventDefault() {prevented = true;}});
    assert.equal(prevented, expected !== undefined);
    if (expected !== undefined) {
        expectSelected(site, expected);
        assert.equal(site.tabs[expected].focusCount, before[expected] + 1);
    }
}

(async () => {
    const site = setup();
    expectSelected(site, 0);
    for (let i = 0; i < 5; i++) {
        site.tabs[i].events.click(); site.tabs[i].events.click(); expectSelected(site, i);
        press(site, i, 'ArrowRight', (i + 1) % 5);
        press(site, i, 'ArrowDown', (i + 1) % 5);
        press(site, i, 'ArrowLeft', (i + 4) % 5);
        press(site, i, 'ArrowUp', (i + 4) % 5);
        press(site, i, 'Home', 0); press(site, i, 'End', 4);
        press(site, i, 'Escape'); press(site, i, 'Tab');
    }
    const linked = setup({hash: '#panel-parallax'}); expectSelected(linked, 2);
    linked.window.location.hash = '#panel-umbra'; linked.window.events.hashchange(); expectSelected(linked, 4);
    linked.window.location.hash = '#install'; linked.window.events.hashchange(); expectSelected(linked, 4);
    expectSelected(setup({selected: 3}), 3);

    for (const button of site.watch) {
        button.events.click(); button.events.click();
        assert(site.dialog.open); assert.equal(site.dialog.showCount, site.playCount());
        site.dialog.events.click({target: site.close}); assert(site.dialog.open, 'dialog contents must not dismiss recording');
        site.close.events.click(); assert(!site.dialog.open); assert(button.focusCount > 0);
    }
    site.watch[0].events.click(); site.dialog.events.click({target: site.dialog}); assert(!site.dialog.open);
    site.watch[1].events.click(); site.dialog.close(); assert(!site.dialog.open); // Native Escape dispatches close.
    assert.equal(site.pauseCount(), 4);
    const legacy = setup({noModal: true}); legacy.watch[0].events.click();
    assert.equal(legacy.window.location.assigned, 'assets/desktop-demo.mp4');
    site.watch[0].events.click(); site.watch[0].isConnected = false;
    const focusBefore = site.watch[0].focusCount; site.dialog.close(); assert.equal(site.watch[0].focusCount, focusBefore);

    await site.copy.events.click(); assert.equal(site.copied(), 'echo example');
    assert(site.status.textContent.startsWith('Copied')); assert.equal(site.copy.disabled, false);
    for (const options of [{denied: true}, {noClipboard: true}]) {
        const unavailable = setup(options); await unavailable.copy.events.click();
        assert.equal(unavailable.selected(), unavailable.code);
        assert(unavailable.status.textContent.includes('unavailable')); assert.equal(unavailable.copy.disabled, false);
    }
    const noSelection = setup({denied: true, nullSelection: true}); await noSelection.copy.events.click();
    assert(noSelection.status.textContent.includes('Select the commands')); assert.equal(noSelection.copy.disabled, false);
    let resolveCopy;
    const pending = setup({pending: new Promise(resolve => {resolveCopy = resolve;})});
    const first = pending.copy.events.click(); assert(pending.copy.disabled); assert.equal(pending.status.textContent, 'Copying commands…');
    await pending.copy.events.click(); assert.equal(pending.writes(), 1);
    resolveCopy(); await first; assert.equal(pending.copy.disabled, false);
    const missing = setup({missingCode: true}); await missing.copy.events.click(); assert.equal(missing.writes(), 0);

    const animated = setup({reveals: true, observer: true}); assert.equal(animated.observed.length, 2);
    animated.observerCallback([{target: animated.reveals[0], isIntersecting: false}]); assert.equal(animated.unobserved.length, 0);
    animated.observerCallback([{target: animated.reveals[0], isIntersecting: true}]);
    assert(animated.reveals[0].classList.values.has('is-visible')); assert.equal(animated.unobserved.length, 1);
    animated.motion.events.change({matches: true}); assert(animated.disconnected());
    assert(animated.reveals.every(item => item.classList.values.has('is-visible')));
    for (const options of [{reveals: true}, {reveals: true, observer: true, reduced: true}]) {
        const fallback = setup(options); assert.equal(fallback.observed.length, 0);
        assert(fallback.reveals.every(item => !item.classList.values.has('reveal-ready')));
    }
    setup({empty: true}); // All five static suite pages must safely share the script.
    await Promise.resolve();
    console.log('Site: tabs, keyboard, deep links, repeated dialog/focus, clipboard success/pending/fallback, optional motion, and static-page safety passed.');
})().catch(error => {console.error(error); process.exitCode = 1;});
