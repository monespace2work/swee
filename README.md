# 📱 Swee - Plateforme de Gestion d'Association

**Swee** est une application mobile moderne conçue pour simplifier la gestion administrative et financière des associations. Elle offre une interface intuitive pour les membres et des outils de contrôle puissants pour les administrateurs.

---

## 🚀 Présentation
Swee permet de digitaliser la vie de votre association en centralisant les informations des membres, le suivi des cotisations et les échanges d'idées. L'application intègre un système de validation rigoureux pour garantir la sécurité et la fiabilité des données.

---

## ✨ Nouveautés Récentes

L'application a été enrichie de fonctionnalités améliorant la réactivité du bureau et la sécurité des opérations :

*   **⚡ Bouton de Validation Rapide :** Un bouton d'action flottant (FAB) intelligent apparaît désormais sur l'accueil du Trésorier et du Président dès qu'une validation est en attente, permettant d'agir en un clic.
*   **🛡️ Sécurisation des Actions :** Introduction de confirmations obligatoires pour toutes les opérations irréversibles (activation de compte, modification de rôle, enregistrement de paiement).
*   **🔔 Système d'Alertes Amélioré :** Notifications locales et pop-ups automatiques pour informer le bureau des nouvelles inscriptions en temps réel.
*   **📖 Inscription Fluidifiée :** Le processus de création de compte membre a été stabilisé pour garantir une transition sans erreur vers la page de connexion.

---

## 📘 Guide des Rôles et Fonctionnalités

L'application Swee repose sur une hiérarchie de rôles permettant une gestion structurée et sécurisée de l'association. Chaque utilisateur possède des privilèges spécifiques adaptés à sa fonction.

### 🟢 1. Le Membre (Utilisateur Standard)
*Le cœur de l'association. Il participe à la vie communautaire et suit ses engagements.*

*   **Fil d'actualité :** Accès aux dernières annonces, photos et événements partagés par le Secrétariat.
*   **Situation Financière :** Consultation en temps réel de son cumul total de versements et accès à l'historique détaillé de ses paiements (Adhésion, Mensualités, Frais exceptionnels).
*   **Boîte à Idées :** Possibilité de soumettre des propositions pour l'amélioration de l'association et de consulter les idées partagées par la communauté.
*   **Profil Personnel :** Gestion de ses informations (photo, contact, adresse). *Note : Toute modification de profil doit être validée par le Secrétaire pour devenir effective.*
*   **Annuaire :** Consultation de la liste des membres actifs de l'association.

### 🔵 2. Le Secrétaire (Gestionnaire Administratif)
*Le garant de l'information et de la base des membres.*

*   **Gestion des Membres :** 
    *   Création de nouveaux profils membres.
    *   Mise à jour des informations administratives.
    *   **Validation des profils :** Approuve ou rejette les demandes de modification de profil envoyées par les membres.
*   **Communication :** Création, modification et suppression des publications sur le fil d'actualité (Posts).
*   **Modération :** Gestion de la boîte à idées (mise en avant ou archivage des suggestions).
*   **Paramètres :** Mise à jour des informations générales de l'association (nom, description, logo).

### 🟡 3. Le Trésorier (Gestionnaire Financier)
*Le gardien des fonds et de la transparence financière.*

*   **Enregistrement des paiements :** Saisie des nouveaux versements (cash, virement, etc.) pour chaque membre.
*   **Gestion financière :** Suivi global des entrées d'argent et vérification de l'historique des transactions.
*   **Validation d'adhésion (Étape 1) :** Lorsqu'un nouveau membre s'inscrit, le Trésorier doit confirmer la réception des frais d'adhésion pour faire passer le membre au statut "En attente Président".

### 🔴 4. Le Président (Autorité Suprême)
*Le superviseur et décideur final.*

*   **Gestion des Rôles :** Seul le Président peut promouvoir un membre à un poste administratif (Secrétaire, Trésorier, Conseiller).
*   **Validation Finale (Étape 2) :** Il donne l'approbation ultime pour l'activation des comptes des nouveaux membres après la validation du Trésorier.
*   **Contrôle :** Accès à la modification du statut de n'importe quel membre (Actif, Suspendu, Désactivé).
*   **Supervision :** Vue d'ensemble sur toutes les activités administratives et financières via son tableau de bord dédié.

### 🟣 5. Le Conseiller (Consultant)
*Rôle d'appui et de consultation.*

*   **Tableau de bord spécifique :** Accès à une vue de supervision pour conseiller le bureau sur les décisions à prendre.
*   **Droits de lecture étendus :** Peut consulter les rapports et les listes pour apporter son expertise sans nécessairement modifier les données opérationnelles.

---

## 🔄 Flux de validation d'un nouveau membre
Pour garantir l'intégrité de l'association, le processus d'adhésion suit ce circuit :
1.  **Enregistrement :** Par le membre ou le Secrétaire (Statut : *En attente Trésorier*).
2.  **Paiement :** Le Trésorier valide la réception de la cotisation (Statut : *En attente Président*).
3.  **Activation :** Le Président valide l'entrée officielle (Statut : *Actif*).

---

## 💻 Installation (Technique)

### Prérequis
*   Flutter SDK (^3.9.0)
*   Firebase Project (Auth, Firestore, Storage)

### Configuration
1.  Cloner le dépôt.
2.  Ajouter votre fichier `google-services.json` (Android) et `GoogleService-Info.plist` (iOS).
3.  Lancer `flutter pub get`.
4.  Exécuter `flutter run`.
