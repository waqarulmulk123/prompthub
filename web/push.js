// onesignal:managed v1 — the single web SDK wrapper; no automatic permission prompt.
window.promptVaultPushReady = false;
window.OneSignalDeferred = window.OneSignalDeferred || [];
window.promptVaultPushRequest = async function () {
  if (!window.promptVaultPushReady) throw new Error('Push is not ready');
  await window.OneSignal.Notifications.requestPermission();
  return window.OneSignal.Notifications.permission;
};
if (location.origin === 'https://promptvault-ai.pages.dev') {
  const script = document.createElement('script');
  script.src = 'https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js';
  script.defer = true;
  document.head.appendChild(script);
  window.OneSignalDeferred.push(async function (OneSignal) {
    try {
      await OneSignal.init({appId: '35457a90-e34c-4e5a-92c7-78aec84ca238', serviceWorkerPath: 'OneSignalSDKWorker.js', notifyButton: {enable: false}, welcomeNotification: {disable: true}});
      window.promptVaultPushReady = true;
    } catch (_) { window.promptVaultPushReady = false; }
  });
}
