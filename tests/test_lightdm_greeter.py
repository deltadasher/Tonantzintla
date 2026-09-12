"""Unit tests for Umbra LightDM web-greeter state machine."""
from pathlib import Path
import subprocess
import unittest


class LightDmGreeterTests(unittest.TestCase):
    def test_greeter_state_machine_with_node_harness(self):
        project_root = Path(__file__).resolve().parents[1]
        greeter_js = project_root / "src/quickshell/modules/umbra/greeter/lightdm/index.js"

        # Node test harness that mocks window, document, and window.lightdm
        test_script = f"""
const fs = require('fs');
const assert = require('assert');

// DOM and environment mock
function createMockEnv(options = {{}}) {{
    const elements = {{
        clock: {{ textContent: '' }},
        date: {{ textContent: '' }},
        username: {{ value: options.username || 'delta', disabled: false, focus: () => {{}} }},
        password: {{ value: options.password || 'secret', disabled: false, focus: () => {{}} }},
        message: {{ textContent: '', classList: {{ toggle: (cls, val) => {{}} }} }},
        login: {{
            listeners: {{}},
            addEventListener: function(event, fn) {{ this.listeners[event] = fn; }}
        }}
    }};

    const horizonListeners = {{}};
    const doc = {{
        getElementById: id => elements[id] || null,
        querySelector: sel => {{
            if (sel === '.horizon') return {{
                addEventListener: (ev, fn) => {{ horizonListeners[ev] = fn; }},
                removeEventListener: (ev, fn) => {{ delete horizonListeners[ev]; }}
            }};
            return null;
        }},
        body: {{
            classList: {{
                classes: new Set(),
                add: function(...cls) {{ cls.forEach(c => this.classes.add(c)); }},
                remove: function(...cls) {{ cls.forEach(c => this.classes.delete(c)); }},
                contains: function(cls) {{ return this.classes.has(cls); }}
            }}
        }}
    }};

    const signals = {{
        show_prompt: [],
        show_message: [],
        authentication_complete: []
    }};

    const calls = [];

    const lightdm = {{
        authentication_user: options.username || 'delta',
        default_session: 'tonantzintla',
        is_authenticated: false,
        authenticate: function(user) {{
            calls.push(['authenticate', user]);
        }},
        respond: function(resp) {{
            calls.push(['respond', resp]);
        }},
        cancel_authentication: function() {{
            calls.push(['cancel_authentication']);
        }},
        start_session_sync: function(sess) {{
            calls.push(['start_session_sync', sess]);
            if (options.failSessionStart) return false;
            return true;
        }},
        show_prompt: {{
            connect: fn => signals.show_prompt.push(fn)
        }},
        show_message: {{
            connect: fn => signals.show_message.push(fn)
        }},
        authentication_complete: {{
            connect: fn => signals.authentication_complete.push(fn)
        }}
    }};

    global.document = doc;
    global.window = {{
        lightdm: lightdm,
        matchMedia: (query) => ({{
            matches: options.reducedMotion === true && query.includes('prefers-reduced-motion')
        }})
    }};

    return {{
        elements,
        doc,
        lightdm,
        signals,
        calls,
        horizonListeners
    }};
}}

const scriptContent = fs.readFileSync('{greeter_js}', 'utf-8');

// Test 1: Successful login flow with prompt response and capture animation end
{{
    const env = createMockEnv();
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    assert.strictEqual(api.getState(), 'idle');
    // Submit form
    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    assert.strictEqual(api.getState(), 'authenticating');
    assert.strictEqual(env.elements.password.disabled, true);
    assert.deepStrictEqual(env.calls[0], ['authenticate', 'delta']);

    // LightDM prompts for password
    env.signals.show_prompt[0]('Password: ', 1);
    assert.deepStrictEqual(env.calls[1], ['respond', 'secret']);

    // LightDM authentication succeeds
    env.lightdm.is_authenticated = true;
    env.signals.authentication_complete[0]();
    assert.strictEqual(api.getState(), 'capture');
    assert.strictEqual(env.doc.body.classList.contains('capture'), true);

    // Animation ends
    assert.strictEqual(typeof env.horizonListeners['animationend'], 'function');
    env.horizonListeners['animationend']();
    assert.strictEqual(api.getState(), 'starting');
    assert.deepStrictEqual(env.calls[2], ['start_session_sync', 'tonantzintla']);
}}

// Test 2: Authentication rejected
{{
    const env = createMockEnv();
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    env.signals.show_prompt[0]('Password: ', 1);

    // Authentication fails
    env.lightdm.is_authenticated = false;
    env.signals.authentication_complete[0]();
    assert.strictEqual(api.getState(), 'idle');
    assert.strictEqual(env.elements.password.disabled, false);
    assert.strictEqual(env.elements.password.value, '');
    assert.strictEqual(env.elements.message.textContent, 'AUTHENTICATION REJECTED');
}}

// Test 3: Duplicate submission while authenticating is ignored
{{
    const env = createMockEnv();
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    assert.strictEqual(api.getState(), 'authenticating');
    assert.strictEqual(env.calls.length, 1);

    // Second submit attempt
    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    assert.strictEqual(env.calls.length, 1); // No second authenticate call
}}

// Test 4: Cancel attempt restores idle state
{{
    const env = createMockEnv();
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    assert.strictEqual(api.getState(), 'authenticating');

    api.cancel();
    assert.strictEqual(api.getState(), 'idle');
    assert.strictEqual(env.elements.password.disabled, false);
    assert.ok(env.calls.some(c => c[0] === 'cancel_authentication'));
}}

// Test 5: Reduced motion skips capture animation delay
{{
    const env = createMockEnv({{ reducedMotion: true }});
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    env.signals.show_prompt[0]('Password: ', 1);
    env.lightdm.is_authenticated = true;
    env.signals.authentication_complete[0]();

    // With reduced motion, capture immediately triggers starting
    assert.strictEqual(api.getState(), 'starting');
    assert.ok(env.calls.some(c => c[0] === 'start_session_sync'));
}}

// Test 6: Failed session launch recovers to idle
{{
    const env = createMockEnv({{ failSessionStart: true }});
    eval(scriptContent);
    const api = global.window.UmbraGreeter;

    env.elements.login.listeners['submit']({{ preventDefault: () => {{}} }});
    env.signals.show_prompt[0]('Password: ', 1);
    env.lightdm.is_authenticated = true;
    env.signals.authentication_complete[0]();
    env.horizonListeners['animationend']();

    // Session launch failed
    assert.strictEqual(api.getState(), 'idle');
    assert.strictEqual(env.elements.password.disabled, false);
    assert.strictEqual(env.elements.message.textContent, 'FAILED TO START SESSION');
}}

console.log('ALL LIGHTDM GREETER TESTS PASSED');
process.exit(0);
"""
        proc = subprocess.run(
            ["node", "-e", test_script],
            capture_output=True,
            text=True,
            timeout=5
        )
        self.assertEqual(proc.returncode, 0, f"STDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
        self.assertIn("ALL LIGHTDM GREETER TESTS PASSED", proc.stdout)


if __name__ == "__main__":
    unittest.main()
