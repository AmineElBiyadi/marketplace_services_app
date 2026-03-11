#  Marketplace de Services Locaux (Flutter + Firebase)

Bienvenue dans le dépôt du projet **Marketplace Services Locaux**, une plateforme mobile et desktop moderne conçue pour connecter les utilisateurs avec des prestataires de services (experts) de manière fluide et sécurisée.

##  Aperçu du Projet
Cette application permet aux clients de rechercher des services, de réserver des interventions, et aux prestataires de gérer leur activité, leurs abonnements et leurs avis. Une interface d'administration complète permet de superviser l'ensemble de l'écosystème.

---

## Stack Technique
- **Framework** : [Flutter](https://flutter.dev/) (Dart) 💙
- **Backend** : [Firebase](https://firebase.google.com/) 🔥
  - **Firestore** : Base de données en temps réel.
  - **Authentication** : Gestion des utilisateurs (Email, Google Sign-In).
  - **Storage** : Stockage des images et documents.
- **Navigation** : [Go Router](https://pub.dev/packages/go_router) 🚦
- **Gestion d'État** : [Provider](https://pub.dev/packages/provider) 📦
- **UI/Icons** : [Lucide Icons](https://lucideicons.io/) ✨
- **Statistiques** : [FL Chart](https://pub.dev/packages/fl_chart) 📊

---

##  Architecture & Modules

###  Module Administration 
Le module Admin a été entièrement refondu pour offrir une expérience "SaaS" moderne :
- **Dashboard Global** : Statistiques en temps réel (CA, Utilisateurs, Croissance).
- **Gestion des Utilisateurs & Prestataires** : Système complet de validation (Approuver/Rejeter).
- **Suivi des Réservations** : Historique détaillé des interventions.
- **Gestion Financière** : Suivi des abonnements packs (Premium/Gratuit).
- **Avis & Réclamations** : Centre de support client.
- **Statistiques Avancées** : Graphiques dynamiques répartis par catégorie.

### 📱 Applications Clients & Experts
- Inscription et profilage.
- Recherche de services par catégorie.
- Système de réservation d'interventions.
- Profil expert avec portfolio et avis.

---

## 🚀 Installation & Configuration

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (dernière version stable).
- [Firebase account](https://console.firebase.google.com/).
- Un émulateur ou un appareil physique.

### Étapes d'installation

1. **Cloner le projet** :
   ```bash
   git clone https://github.com/AmineElBiyadi/marketplace_services_app.git
   cd marketplace_services_app
   ```

2. **Accéder au dossier de l'application** :
   ```bash
   cd service_app
   ```

3. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

4. **Configurer Firebase** :
   - Ajoutez vos fichiers `google-services.json` (Android) et `GoogleService-Info.plist` (iOS).
   - Configurez Firebase via la CLI Flutter : `flutterfire configure`.

5. **Lancer l'application** :
   ```bash
   flutter run
   ```

---

##  Structure du Code (`lib/`)
- `screens/admin` : Écrans du tableau de bord d'administration.
- `services/` : Logique d'interaction avec Firebase (Firestore, Auth).
- `layouts/` : Structures de page réutilisables (Sidebar/TopBar).
- `widgets/` : Composants UI personnalisés.
- `models/` : Modèles de données (User, Provider, Intervention).


