import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/notification_model.dart';
import 'fcm_v1_service.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── FCM & LOCAL NOTIFICATIONS ──────────────────────────────

  static Future<void> initialize() async {
    // Request permission (especially for iOS and Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click here
        print('Notification clicked: ${response.payload}');
      },
    );

    // Create notification channel for Android (required for high importance)
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Configure foreground notification presentation
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the FCM token
    String? token = await _firebaseMessaging.getToken();
    print("FCM Token: $token");

    // Listen to messages in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message while in the foreground!');
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle background/terminated state when app is opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened via notification: ${message.messageId}');
    });

    // Check if the app was opened from a terminated state via a notification
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state via notification: ${initialMessage.messageId}');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
  }

  // ─── FIRESTORE NOTIFICATIONS ──────────────────────────────

  Stream<List<NotificationModel>> getNotifications(String idUtilisateur) {
    return _firestore
        .collection('notifications')
        .where('idUtilisateur', isEqualTo: idUtilisateur)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
  }

  Stream<int> getUnreadCount(String idUtilisateur) {
    return _firestore
        .collection('notifications')
        .where('idUtilisateur', isEqualTo: idUtilisateur)
        .where('estLue', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'estLue': true,
      });
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead(String idUtilisateur) async {
    try {
      final batch = _firestore.batch();
      final snapshots = await _firestore
          .collection('notifications')
          .where('idUtilisateur', isEqualTo: idUtilisateur)
          .where('estLue', isEqualTo: false)
          .get();

      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {'estLue': true});
      }
      await batch.commit();
    } catch (e) {
      print("Error marking all notifications as read: $e");
    }
  }

  Future<void> sendNotification({
    required String idUtilisateur,
    required String titre,
    required String corps,
    required String type,
    String? relatedId,
  }) async {
    try {
      // 1. Create notification in Firestore (for the in-app list)
      final notification = NotificationModel(
        id: '', 
        idUtilisateur: idUtilisateur,
        titre: titre,
        corps: corps,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
      );
      
      await _firestore.collection('notifications').add(notification.toMap());
      print("Notification added to Firestore for $idUtilisateur");
      
      // 2. Fetch the client's FCM token to send a real Push Notification
      final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
      final String? token = userDoc.data()?['token'];

      if (token != null && token.isNotEmpty) {
        print("FCM Token found for $idUtilisateur, triggering real push notification...");
        
        await FCMV1Service.sendPushNotification(
          deviceToken: token,
          title: titre,
          body: corps,
          data: {
            "type": type,
            if (relatedId != null) "id": relatedId,
          },
        );
      } else {
        print("No FCM Token found for $idUtilisateur");
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> sendNotificationModel(NotificationModel notification) async {
    try {
      await _firestore.collection('notifications').add(notification.toMap());
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  static Future<void> updateUserToken(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).update({
          'token': token,
          'updated_At': FieldValue.serverTimestamp(),
        });
        print("Updated FCM Token for user $userId");
      }
    } catch (e) {
      print("Error updating user FCM token: $e");
    }
  }

  /// Call this on LOGOUT to prevent the old account from receiving notifications
  /// on this device after another account logs in.
  static Future<void> deleteUserToken(String userId) async {
    try {
      // 1. Invalidate the FCM token on Firebase side (new token will be generated on next login)
      await _firebaseMessaging.deleteToken();
      print("FCM Token deleted from Firebase for user $userId");

      // 2. Remove the token from Firestore so no one can send to this stale token
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).update({
        'token': FieldValue.delete(),
        'updated_At': FieldValue.serverTimestamp(),
      });
      print("FCM Token removed from Firestore for user $userId");
    } catch (e) {
      print("Error deleting user FCM token: $e");
    }
  }
}
