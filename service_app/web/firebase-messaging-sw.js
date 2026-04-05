importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase in the service worker with your actual project configuration
firebase.initializeApp({
  apiKey: "AIzaSyCXUbE65hOtCOEeUuq_8cWvX0Tmjh--V1s",
  authDomain: "presto-daaed.firebaseapp.com",
  projectId: "presto-daaed",
  storageBucket: "presto-daaed.firebasestorage.app",
  messagingSenderId: "112121777645",
  appId: "1:112121777645:web:c01a700e7b5b0cd851ebe4",
  measurementId: "G-302X5H568V"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.ico',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
