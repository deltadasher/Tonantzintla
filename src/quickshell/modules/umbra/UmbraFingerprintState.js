.pragma library

function state(authenticating, method, failed, unlocking) {
    if (unlocking) return "success";
    if (method !== "fingerprint") return "ready";
    if (authenticating) return "pending";
    return failed ? "failed" : "ready";
}
