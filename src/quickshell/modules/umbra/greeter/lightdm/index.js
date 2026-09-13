/* web-greeter exposes lightdm only on the login screen; keep a browser preview usable. */
(function() {
  'use strict';

  const $ = id => document.getElementById(id);

  const getLightDM = () => (typeof window !== 'undefined' && window.lightdm)
    ? window.lightdm
    : (typeof lightdm !== 'undefined' ? lightdm : null);

  const displayTime = () => {
    const clock = $("clock");
    const date = $("date");
    if (!clock || !date) return;
    const now = new Date();
    clock.textContent = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    date.textContent = now.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" });
  };
  const clockInterval = setInterval(displayTime, 1000);
  if (clockInterval && typeof clockInterval.unref === 'function') {
    clockInterval.unref();
  }

  // Explicit states: idle -> authenticating -> capture -> starting -> error/idle
  let state = "idle";
  let pendingPassword = null;
  let selectedUser = "";
  let selectedSession = "";
  let captureTimer = null;
  let captureAnimationHandled = false;

  function setStatus(msg, isError = false) {
    const el = $("message");
    if (!el) return;
    el.textContent = msg || "";
    el.classList.toggle("error", isError);
  }

  function setInputsDisabled(disabled) {
    const usernameInput = $("username");
    const passwordInput = $("password");
    const submitBtn = $("submit-btn") || (document.querySelector("#login button[type=submit]"));
    if (usernameInput) usernameInput.disabled = disabled;
    if (passwordInput) passwordInput.disabled = disabled;
    if (submitBtn) submitBtn.disabled = disabled;
  }

  function clearCredentials() {
    pendingPassword = null;
    const passwordInput = $("password");
    if (passwordInput) passwordInput.value = "";
  }

  function cancelAttempt() {
    if (captureTimer) {
      clearTimeout(captureTimer);
      captureTimer = null;
    }
    clearCredentials();
    const ldm = getLightDM();
    if (ldm && (state === "authenticating" || state === "capture")) {
      try {
        ldm.cancel_authentication();
      } catch (e) {
        /* ignore cancel error */
      }
    }
    document.body.classList.remove("authenticating", "capture");
    setInputsDisabled(false);
    state = "idle";
  }

  function onCaptureComplete() {
    if (captureAnimationHandled) return;
    captureAnimationHandled = true;
    if (captureTimer) {
      clearTimeout(captureTimer);
      captureTimer = null;
    }

    const ldm = getLightDM();
    if (state !== "capture" || !ldm || !ldm.is_authenticated) {
      cancelAttempt();
      return;
    }

    state = "starting";
    try {
      const sessionToStart = selectedSession || ldm.default_session || "";
      const success = ldm.start_session_sync(sessionToStart);
      if (success === false) {
        throw new Error("Session launch rejected");
      }
    } catch (err) {
      setStatus("FAILED TO START SESSION", true);
      document.body.classList.remove("authenticating", "capture");
      setInputsDisabled(false);
      state = "idle";
    }
  }

  function beginCapture() {
    state = "capture";
    document.body.classList.add("capture");
    captureAnimationHandled = false;

    // Check for prefers-reduced-motion
    const prefersReducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) {
      onCaptureComplete();
      return;
    }

    // Listen for animationend on the horizon element
    const horizon = document.querySelector(".horizon");
    if (horizon) {
      const onAnimEnd = () => {
        horizon.removeEventListener("animationend", onAnimEnd);
        onCaptureComplete();
      };
      horizon.addEventListener("animationend", onAnimEnd);
    }

    // Bounded fallback timeout (1200ms) in case animationend does not fire
    captureTimer = setTimeout(onCaptureComplete, 1200);
  }

  function initLightDM() {
    const ldm = getLightDM();
    if (!ldm) return;

    if ($("username")) {
      $("username").value = ldm.authentication_user || "";
    }
    selectedSession = ldm.default_session || "";

    if (ldm.show_prompt && ldm.show_prompt.connect) {
      ldm.show_prompt.connect((text, type) => {
        if (state !== "authenticating") return;
        if (pendingPassword !== null) {
          const secret = pendingPassword;
          pendingPassword = null;
          ldm.respond(secret);
        } else {
          // If a subsequent prompt arrives or prompt is interactive
          setInputsDisabled(false);
          const passwordInput = $("password");
          if (passwordInput) {
            passwordInput.placeholder = text || "Password";
            passwordInput.focus();
          }
        }
      });
    }

    if (ldm.show_message && ldm.show_message.connect) {
      ldm.show_message.connect((text, type) => {
        setStatus(text, type === 1);
      });
    }

    if (ldm.authentication_complete && ldm.authentication_complete.connect) {
      ldm.authentication_complete.connect(() => {
        if (state !== "authenticating") return;
        if (ldm.is_authenticated) {
          setStatus("");
          beginCapture();
        } else {
          state = "error";
          clearCredentials();
          setStatus("AUTHENTICATION REJECTED", true);
          document.body.classList.remove("authenticating");
          setInputsDisabled(false);
          const passwordInput = $("password");
          if (passwordInput) {
            passwordInput.value = "";
            passwordInput.focus();
          }
          state = "idle";
        }
      });
    }
  }

  function handleLoginSubmit(event) {
    if (event) event.preventDefault();

    if (state !== "idle") {
      // Duplicate submission ignored
      return;
    }

    const ldm = getLightDM();
    if (!ldm) {
      setStatus("Preview only — LightDM is not connected.", true);
      return;
    }

    const usernameInput = $("username");
    const passwordInput = $("password");
    if (!usernameInput || !passwordInput) return;

    selectedUser = usernameInput.value.trim();
    pendingPassword = passwordInput.value;
    if (!selectedUser) {
      setStatus("IDENTITY REQUIRED", true);
      usernameInput.focus();
      return;
    }

    // Transition to authenticating
    state = "authenticating";
    setStatus("");
    document.body.classList.add("authenticating");
    setInputsDisabled(true);

    try {
      ldm.authenticate(selectedUser);
    } catch (err) {
      state = "error";
      clearCredentials();
      setStatus("AUTHENTICATION SERVICE ERROR", true);
      document.body.classList.remove("authenticating");
      setInputsDisabled(false);
      state = "idle";
    }
  }

  const loginForm = $("login");
  if (loginForm) {
    loginForm.addEventListener("submit", handleLoginSubmit);
  }

  initLightDM();

  // Expose state machine for testing and diagnosis
  const greeterApi = {
    getState: () => state,
    submit: handleLoginSubmit,
    cancel: cancelAttempt,
    beginCapture: beginCapture,
    onCaptureComplete: onCaptureComplete,
    init: initLightDM
  };

  if (typeof window !== 'undefined') {
    window.UmbraGreeter = greeterApi;
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = greeterApi;
  }
})();
