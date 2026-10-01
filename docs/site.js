(() => {
    'use strict';

    const tabs = [...document.querySelectorAll('[data-instrument]')];
    const panelFor = tab => document.getElementById(tab.getAttribute('aria-controls'));

    function selectTab(tab, focus = false) {
        if (!tab || !panelFor(tab)) return;
        tabs.forEach(item => {
            const selected = item === tab;
            item.setAttribute('aria-selected', String(selected));
            item.tabIndex = selected ? 0 : -1;
            const panel = panelFor(item);
            if (panel) panel.hidden = !selected;
        });
        if (focus) tab.focus();
        if (typeof window.CustomEvent === 'function') {
            document.dispatchEvent(new window.CustomEvent('tonantzintla:instrument', { detail: { id: tab.dataset.instrument } }));
        }
    }

    tabs.forEach((tab, index) => {
        tab.addEventListener('click', () => selectTab(tab));
        tab.addEventListener('keydown', event => {
            let next;
            if (event.key === 'ArrowRight' || event.key === 'ArrowDown') next = (index + 1) % tabs.length;
            if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') next = (index + tabs.length - 1) % tabs.length;
            if (event.key === 'Home') next = 0;
            if (event.key === 'End') next = tabs.length - 1;
            if (next === undefined) return;
            event.preventDefault();
            selectTab(tabs[next], true);
        });
    });

    function selectLinkedPanel() {
        const linked = tabs.find(tab => `#${tab.getAttribute('aria-controls')}` === window.location.hash);
        if (linked) selectTab(linked);
    }
    if (tabs.length) {
        selectTab(tabs.find(tab => tab.getAttribute('aria-selected') === 'true') || tabs[0]);
        selectLinkedPanel();
        window.addEventListener('hashchange', selectLinkedPanel);
    }

    const dialog = document.querySelector('#demo-dialog');
    const watchButtons = [...document.querySelectorAll('[data-watch]')];
    if (dialog) {
        const video = dialog.querySelector('video');
        const close = dialog.querySelector('[data-close-demo]');
        let opener;
        watchButtons.forEach(button => button.addEventListener('click', () => {
            if (dialog.open) return;
            if (typeof dialog.showModal !== 'function') {
                const recording = dialog.querySelector('source')?.getAttribute('src');
                if (recording) window.location.assign(recording);
                return;
            }
            opener = button;
            dialog.showModal();
            const playback = video?.play();
            playback?.catch(() => { /* Native playback controls remain available. */ });
        }));
        close?.addEventListener('click', () => dialog.close());
        dialog.addEventListener('close', () => {
            video?.pause();
            if (opener?.isConnected !== false) opener?.focus({preventScroll: true});
        });
        dialog.addEventListener('click', event => {
            if (event.target === dialog) dialog.close();
        });
    }

    const copy = document.querySelector('#copy-install');
    copy?.addEventListener('click', async () => {
        if (copy.disabled) return;
        const code = document.querySelector('#install-commands');
        const status = document.querySelector('#copy-status');
        if (!code || !status) return;
        copy.disabled = true;
        status.textContent = 'Copying commands…';
        try {
            await navigator.clipboard.writeText(code.textContent.trim());
            status.textContent = 'Copied. Read the installation notes before running.';
        } catch {
            const selection = window.getSelection();
            if (selection) {
                const range = document.createRange();
                range.selectNodeContents(code);
                selection.removeAllRanges();
                selection.addRange(range);
                status.textContent = 'Automatic copy is unavailable. Commands selected; copy them manually.';
            } else {
                status.textContent = 'Automatic copy is unavailable. Select the commands and copy them manually.';
            }
        } finally {
            copy.disabled = false;
        }
    });

    // Content stays visible unless this optional enhancement is available.
    const reveals = [...document.querySelectorAll('[data-reveal]')];
    const motion = window.matchMedia?.('(prefers-reduced-motion: reduce)');
    if (reveals.length && !motion?.matches && 'IntersectionObserver' in window) {
        const observer = new window.IntersectionObserver(entries => {
            entries.forEach(entry => {
                if (!entry.isIntersecting) return;
                entry.target.classList.add('is-visible');
                observer.unobserve(entry.target);
            });
        }, {threshold: 0.08});
        reveals.forEach(element => {
            element.classList.add('reveal-ready');
            observer.observe(element);
        });
        motion?.addEventListener('change', event => {
            if (!event.matches) return;
            observer.disconnect();
            reveals.forEach(element => element.classList.add('is-visible'));
        });
    }
})();
