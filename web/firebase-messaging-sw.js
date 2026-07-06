// Firebase Cloud Messaging service worker.
// Handles background/closed-tab push notifications on web.
// Must be served from the root path (/firebase-messaging-sw.js).
// Firebase config values here are public (same as firebase_options.dart).
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCZQAAa0UQWOA6owZm-adBirUJcBdFZZUg',
  authDomain: 'dharmaai-f0078.firebaseapp.com',
  projectId: 'dharmaai-f0078',
  storageBucket: 'dharmaai-f0078.firebasestorage.app',
  messagingSenderId: '494796756772',
  appId: '1:494796756772:web:d3c8c1840472fc816a05b1',
  measurementId: 'G-HW138CH39L',
});

const messaging = firebase.messaging();

// Show a notification when the app tab is not focused.
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;
  self.registration.showNotification(title, {
    body: body ?? '',
    icon: '/icons/Icon-192.png',
  });
});
