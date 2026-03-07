import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ← essentiel pour Web
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> _initFirebase = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: _initFirebase,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return FirestoreTestPage();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur Firebase: ${snapshot.error}'));
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class FirestoreTestPage extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void addTestUser() async {
    try {
      await firestore.collection('users').add({
        'name': 'Douae',
        'email': 'douae@test.com',
        'role': 'client',
      });
      print("✅ User ajouté avec succès");
    } catch (e) {
      print("❌ Erreur: $e");
    }
  }

  void readUsers() async {
    try {
      QuerySnapshot snapshot = await firestore.collection('users').get();
      for (var doc in snapshot.docs) {
        print(doc.data());
      }
    } catch (e) {
      print("❌ Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Test Firestore")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: addTestUser,
              child: Text("Ajouter un utilisateur"),
            ),
            ElevatedButton(
              onPressed: readUsers,
              child: Text("Lire les utilisateurs"),
            ),
          ],
        ),
      ),
    );
  }
}