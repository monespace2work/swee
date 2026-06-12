import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/member_model.dart';
import '../models/payment_model.dart';
import '../models/post_model.dart';
import '../models/idea_model.dart';
import '../models/alert_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // MEMBERS
  Future<void> createMember(MemberModel member) async {
    await _db.collection('members').doc(member.id).set(member.toMap());
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    await _db.collection('members').doc(id).update(data);
  }

  Stream<List<MemberModel>> getMembers() {
    return _db.collection('members').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MemberModel.fromMap(doc.data(), doc.id)).toList());
  }

  // PAYMENTS
  Future<void> addPayment(PaymentModel payment) async {
    await _db.collection('payments').add(payment.toMap());
  }

  Stream<List<PaymentModel>> getMemberPayments(String memberId) {
    return _db
        .collection('payments')
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snapshot) {
      final payments = snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
      // Tri manuel côté client pour éviter de demander un index composite Firestore
      payments.sort((a, b) => b.date.compareTo(a.date));
      return payments;
    });
  }

  Stream<List<PaymentModel>> getAllPayments() {
    return _db
        .collection('payments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PaymentModel.fromMap(doc.data(), doc.id)).toList());
  }

  // POSTS
  Future<void> addPost(PostModel post) async {
    await _db.collection('posts').add(post.toMap());
  }

  Future<void> updatePost(String id, Map<String, dynamic> data) async {
    await _db.collection('posts').doc(id).update(data);
  }

  Future<void> deletePost(String id) async {
    await _db.collection('posts').doc(id).delete();
  }

  Stream<List<PostModel>> getPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PostModel.fromMap(doc.data(), doc.id)).toList());
  }

  // VOTES
  Future<void> votePost(String postId, String memberId, String voteType) async {
    await _db.collection('posts').doc(postId).update({
      'votes.$memberId': voteType,
    });
  }

  // COMMENTS
  Future<void> addComment(CommentModel comment) async {
    await _db.collection('comments').add(comment.toMap());
  }

  Stream<List<CommentModel>> getComments(String postId) {
    return _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
          .toList();
      // Tri manuel pour éviter l'obligation d'un index composite Firestore
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    });
  }

  // IDEAS
  Future<void> addIdea(IdeaModel idea) async {
    await _db.collection('ideas').add(idea.toMap());
  }

  Future<void> updateIdea(String id, Map<String, dynamic> data) async {
    await _db.collection('ideas').doc(id).update(data);
  }

  Stream<List<IdeaModel>> getMemberIdeas(String memberId) {
    return _db
        .collection('ideas')
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snapshot) {
      final ideas = snapshot.docs
          .map((doc) => IdeaModel.fromMap(doc.data(), doc.id))
          .toList();
      // Tri côté client pour éviter de créer un index composite Firestore
      ideas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ideas;
    });
  }

  Stream<List<IdeaModel>> getAllIdeas() {
    return _db
        .collection('ideas')
        .snapshots()
        .map((snapshot) {
      final ideas = snapshot.docs
          .map((doc) => IdeaModel.fromMap(doc.data(), doc.id))
          .toList();
      // Tri côté client pour éviter de créer un index composite Firestore
      ideas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ideas;
    });
  }

  // ASSOCIATION SETTINGS
  Future<void> updateAssociationSettings(Map<String, dynamic> data) async {
    await _db.collection('settings').doc('association').set(data, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> getAssociationSettings() {
    return _db.collection('settings').doc('association').snapshots().map((doc) => doc.data() ?? {});
  }

  // ALERTS
  Future<void> addAlert(AlertModel alert) async {
    await _db.collection('alerts').add(alert.toMap());
  }

  Future<void> updateAlert(String id, Map<String, dynamic> data) async {
    await _db.collection('alerts').doc(id).update(data);
  }

  Future<void> deleteAlert(String id) async {
    await _db.collection('alerts').doc(id).delete();
  }

  Stream<List<AlertModel>> getAlertsByInitiator(String adminId) {
    return _db
        .collection('alerts')
        .where('initiatorId', isEqualTo: adminId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AlertModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<AlertModel>> getPendingAlertsForUser(String userId, UserRole role) {
    return _db
        .collection('alerts')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => AlertModel.fromMap(doc.data(), doc.id))
          .where((alert) {
        // Not yet viewed or dismissed by this user
        if (alert.viewedBy.containsKey(userId) || alert.dismissedBy.containsKey(userId)) return false;
        
        // Check remindMeLater
        if (alert.remindMeLater.containsKey(userId)) {
          final remindAt = alert.remindMeLater[userId]!;
          if (now.isBefore(remindAt)) return false;
        }

        // Started already
        if (alert.startDate.isAfter(now)) return false;

        // Target audience check
        switch (alert.targetType) {
          case AlertTarget.all:
            return true;
          case AlertTarget.bureau:
            return role == UserRole.president || role == UserRole.secretaire || role == UserRole.tresorier;
          case AlertTarget.ordinary:
            return role == UserRole.membre;
          case AlertTarget.manual:
            return alert.targetUserIds.contains(userId);
        }
      }).toList();
    });
  }

  Stream<List<AlertModel>> getRelevantAlertsForUser(String userId, UserRole role) {
    return _db
        .collection('alerts')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => AlertModel.fromMap(doc.data(), doc.id))
          .where((alert) {
        // Not dismissed by this user
        if (alert.dismissedBy.containsKey(userId)) return false;

        // Started already
        if (alert.startDate.isAfter(now)) return false;

        // Target audience check
        switch (alert.targetType) {
          case AlertTarget.all:
            return true;
          case AlertTarget.bureau:
            return role == UserRole.president || role == UserRole.secretaire || role == UserRole.tresorier;
          case AlertTarget.ordinary:
            return role == UserRole.membre;
          case AlertTarget.manual:
            return alert.targetUserIds.contains(userId);
        }
      }).toList();
    });
  }

  Future<void> markAlertAsViewed(String alertId, String userId) async {
    await _db.collection('alerts').doc(alertId).update({
      'viewedBy.$userId': FieldValue.serverTimestamp(),
      'remindMeLater.$userId': FieldValue.delete(),
    });
  }

  Future<void> dismissAlertForUser(String alertId, String userId) async {
    await _db.collection('alerts').doc(alertId).update({
      'dismissedBy.$userId': FieldValue.serverTimestamp(),
      'remindMeLater.$userId': FieldValue.delete(),
    });
  }

  Future<void> setAlertReminder(String alertId, String userId, Duration duration) async {
    final remindAt = DateTime.now().add(duration);
    await _db.collection('alerts').doc(alertId).update({
      'remindMeLater.$userId': Timestamp.fromDate(remindAt),
    });
  }
}
