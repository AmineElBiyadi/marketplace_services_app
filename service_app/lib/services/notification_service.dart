import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // MARK: - SEND NOTIFICATION
  Future<void> sendNotification({
    required String idUtilisateur,
    required String titre,
    required String corps,
    required String type, 
    String? relatedId,
  }) async {
    try {
      await _db.collection('notifications').add({
        'idUtilisateur': idUtilisateur,
        'titre': titre,
        'corps': corps,
        'type': type,
        'relatedId': relatedId,
        'estLue': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('DEBUG: Notification sent to $idUtilisateur');
    } catch (e) {
      debugPrint('ERROR sending notification: $e');
    }
  }

  // MARK: - STREAMS
  
  /// Stream to get the UNREAD count for a given user
  Stream<int> getUnreadCount(String idUtilisateur) {
    return _db
        .collection('notifications')
        .where('idUtilisateur', isEqualTo: idUtilisateur)
        .where('estLue', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream to get all notifications for a given user
  Stream<List<NotificationModel>> getNotifications(String idUtilisateur) {
    return _db
        .collection('notifications')
        .where('idUtilisateur', isEqualTo: idUtilisateur)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  // MARK: - ACTIONS
  
  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'estLue': true,
    });
  }

  Future<void> markAllAsRead(String idUtilisateur) async {
    final unreadSnap = await _db
        .collection('notifications')
        .where('idUtilisateur', isEqualTo: idUtilisateur)
        .where('estLue', isEqualTo: false)
        .get();

    if (unreadSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (var doc in unreadSnap.docs) {
      batch.update(doc.reference, {'estLue': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).delete();
  }
}
