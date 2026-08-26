/* web-greeter exposes lightdm only on the login screen; keep a browser preview usable. */
const $ = id => document.getElementById(id);
const displayTime = () => { const now = new Date(); $("clock").textContent = now.toLocaleTimeString([], {hour:"2-digit",minute:"2-digit"}); $("date").textContent = now.toLocaleDateString([], {weekday:"long",month:"long",day:"numeric"}); };
displayTime(); setInterval(displayTime, 1000);
if (window.lightdm) {
  $("username").value = lightdm.authentication_user || "";
  lightdm.authentication_complete.connect(() => {
    if (lightdm.is_authenticated) lightdm.start_session_sync(lightdm.default_session || "");
    else { $("message").textContent = "AUTHENTICATION REJECTED"; $("password").value = ""; $("password").focus(); }
  });
}
$("login").addEventListener("submit", event => { event.preventDefault(); if (!window.lightdm) { $("message").textContent = "Preview only — LightDM is not connected."; return; } $("message").textContent = ""; lightdm.authenticate($("username").value); lightdm.respond($("password").value); });
