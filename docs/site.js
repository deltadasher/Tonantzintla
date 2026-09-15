(() => {
  const tabs = [...document.querySelectorAll('[data-instrument]')];
  function selectTab(tab) {
    tabs.forEach(item => {
      const selected = item === tab;
      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
      document.getElementById(item.getAttribute('aria-controls')).hidden = !selected;
    });
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
      event.preventDefault(); selectTab(tabs[next]); tabs[next].focus();
    });
  });
  const dialog = document.querySelector('#demo-dialog');
  if (dialog) {
    const video = dialog.querySelector('video');
    document.querySelector('[data-watch]').addEventListener('click', () => {
      dialog.showModal();
      video.play().catch(() => { /* Native controls remain available if autoplay is blocked. */ });
    });
    dialog.querySelector('[data-close-demo]').addEventListener('click', () => dialog.close());
    dialog.addEventListener('close', () => video.pause());
    dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  }
  const copy = document.querySelector('#copy-install');
  copy?.addEventListener('click', async () => {
    const code = document.querySelector('#install-commands');
    const status = document.querySelector('#copy-status');
    try {
      await navigator.clipboard.writeText(code.textContent.trim());
      status.textContent = 'Copied. Read the installation notes before running.';
    } catch {
      const selection = window.getSelection();
      const range = document.createRange(); range.selectNodeContents(code);
      selection.removeAllRanges(); selection.addRange(range);
      status.textContent = 'Automatic copy is unavailable. Commands selected; copy them manually.';
    }
  });
})();
