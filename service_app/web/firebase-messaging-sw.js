importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase in the service worker with your actual project configuration
firebase.initializeApp({
  apiKey: "AIzaSyBUx86H9Pk8sZ9LFeWM_1maqSyg908sP8Y",
  authDomain: "services-app-70555.firebaseapp.com",
  projectId: "services-app-70555",
  storageBucket: "services-app-70555.firebasestorage.app",
  messagingSenderId: "1003192210122",
  appId: "1:1003192210122:web:3c88d98839ad0c4373da33",
  measurementId: "G-9J1GMHXPGM"
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
