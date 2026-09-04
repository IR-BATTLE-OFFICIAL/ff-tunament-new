import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/data/models/transaction_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Stream<User?> get user => _auth.authStateChanges();

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
      return 'unknown_device';
    } catch (e) {
      return 'error_getting_id';
    }
  }

  Future<bool> _canRegisterOnDevice(String deviceId) async {
    try {
      final snapshot = await _db.collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get();
      return snapshot.docs.length < 2;
    } catch (e) {
      debugPrint("Check limit error: $e");
      return true;
    }
  }

  Future<void> deposit(String uid, double amount) async {
    try {
      UserModel? user = await getUserData(uid);
      if (user == null) throw Exception("User not found");
      
      double newBalance = user.balance + amount;
      await updateBalance(uid, newBalance);
      
      final tx = {
        'userId': uid,
        'amount': amount,
        'type': 'deposit',
        'dateTime': Timestamp.now(),
        'status': 'success',
        'description': 'Deposited ₹$amount to wallet',
      };
      await _db.collection('transactions').add(tx);
    } catch (e) {
      debugPrint("Deposit error: $e");
      rethrow;
    }
  }

  Future<void> adminUpdateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> updateBalance(String uid, double newBalance) async {
    await _db.collection('users').doc(uid).update({'balance': newBalance});
  }

  Future<void> resetUnreadCount(String uid) async {
    await _db.collection('users').doc(uid).update({'unreadNotifications': 0});
  }

  Future<void> incrementUnreadCount(String uid) async {
    await _db.collection('users').doc(uid).update({
      'unreadNotifications': FieldValue.increment(1)
    });
  }

  Future<void> incrementAllUsersUnreadCount() async {
    try {
      final snapshot = await _db.collection('users').get();
      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'unreadNotifications': FieldValue.increment(1)
        });
      }
    } catch (e) {
      debugPrint("Error incrementing all users: $e");
    }
  }

  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final txs = snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList();
          txs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return txs;
        });
  }

  Future<void> clearUserTransactions(String userId) async {
    final snapshot = await _db.collection('transactions').where('userId', isEqualTo: userId).get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }

      // Auto-create missing user doc for authenticated users
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        final newUser = UserModel(
          uid: uid,
          name: currentUser.displayName ?? (currentUser.email != null ? currentUser.email!.split('@').first : 'Gamer'),
          email: currentUser.email ?? '',
          phone: currentUser.phoneNumber,
          balance: 0.0,
          totalWins: 0,
          totalEarnings: 0.0,
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(uid).set(newUser.toMap(), SetOptions(merge: true));
        return newUser;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user from Firestore: $e");
      return null;
    }
  }

  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<UserModel>> getTopEarners() {
    return _db.collection('users').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      list.sort((a, b) {
        double coinA = a.totalEarnings > a.balance ? a.totalEarnings : a.balance;
        double coinB = b.totalEarnings > b.balance ? b.totalEarnings : b.balance;
        return coinB.compareTo(coinA);
      });
      return list;
    });
  }

  Future<UserCredential?> signUpWithEmail(String email, String password, String name, {String? phone, String? ffUid, String? referralCode}) async {
    User? userToDelete;
    try {
      String deviceId = await _getDeviceId();

      // 1. Create User in Firebase Auth first
      // This makes the user "Authenticated" so Firestore Rules like "allow read: if request.auth != null" will pass.
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      userToDelete = userCredential.user;

      // 2. Now that user is authenticated, perform checks
      
      // Check device limit
      if (!await _canRegisterOnDevice(deviceId)) {
        throw Exception("Device registration limit reached (Max 2 accounts per phone).");
      }

      // Check if username already exists
      final existingName = await _db.collection('users')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      
      if (existingName.docs.isNotEmpty) {
        throw Exception("Username already taken. Please use a different name.");
      }

      // Check if Free Fire UID already exists
      if (ffUid != null && ffUid.isNotEmpty) {
        final existingFF = await _db.collection('users')
            .where('ffUid', isEqualTo: ffUid)
            .limit(1)
            .get();
        
        if (existingFF.docs.isNotEmpty) {
          throw Exception("Free Fire UID already registered.");
        }
      }

      String? referredBy;
      double initialBonus = 0.0;

      // Fetch dynamic bonus amount from config
      DocumentSnapshot configDoc = await _db.collection('settings').doc('app_config').get();
      double configSignupBonus = 5.0;
      if (configDoc.exists) {
        final config = configDoc.data() as Map<String, dynamic>;
        configSignupBonus = (config['referralSignupBonus'] ?? 5.0).toDouble();
      }

      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final response = await _db.collection('users')
              .where('referralCode', isEqualTo: referralCode.toUpperCase())
              .limit(1)
              .get();
          
          if (response.docs.isNotEmpty) {
            referredBy = response.docs.first.id;
            initialBonus = configSignupBonus;
          }
        } catch (e) {
          debugPrint("Referral check error: $e");
        }
      }

      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        ffUid: ffUid,
        profilePic: '',
        balance: 0.0,
        bonusBalance: initialBonus,
        totalWins: 0,
        totalEarnings: 0.0,
        referralCode: userCredential.user!.uid.substring(0, 8).toUpperCase(),
        referredBy: referredBy,
        isAdmin: false,
        deviceId: deviceId,
        createdAt: DateTime.now(),
      );
      
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
      await _sendWelcomeNotification(newUser.uid);

      // Increment playerCount field in settings/app_config
      try {
        await _db.collection('settings').doc('app_config').update({
          'playerCount': FieldValue.increment(1)
        });
      } catch (e) {
        debugPrint("Error incrementing playerCount on email signup: $e");
      }

      if (initialBonus > 0) {
        final tx = {
          'userId': newUser.uid,
          'amount': initialBonus,
          'type': 'referral_bonus',
          'dateTime': Timestamp.now(),
          'status': 'success',
          'description': 'Signup bonus from referral',
        };
        await _db.collection('transactions').add(tx);
      }

      return userCredential;
    } catch (e) {
      debugPrint("Auth Error: $e");
      // If checks failed after Auth creation, delete the Auth account to allow retrying
      if (userToDelete != null) {
        try {
          await userToDelete.delete();
        } catch (delError) {
          debugPrint("Error deleting user after failed signup: $delError");
        }
      }
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("Error signing in with email: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      UserModel? existingUser = await getUserData(userCredential.user!.uid);
      if (existingUser == null) {
        String deviceId = await _getDeviceId();
        if (!await _canRegisterOnDevice(deviceId)) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw Exception("Device registration limit reached.");
        }

        UserModel newUser = UserModel(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'Player',
          email: userCredential.user!.email,
          profilePic: userCredential.user!.photoURL,
          balance: 0.0,
          totalWins: 0,
          totalEarnings: 0.0,
          referralCode: userCredential.user!.uid.substring(0, 8).toUpperCase(),
          isAdmin: false,
          deviceId: deviceId,
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
        await _sendWelcomeNotification(newUser.uid);

        // Increment playerCount field in settings/app_config
        try {
          await _db.collection('settings').doc('app_config').update({
            'playerCount': FieldValue.increment(1)
          });
        } catch (e) {
          debugPrint("Error incrementing playerCount on Google signup: $e");
        }
      }
      
      return userCredential;
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    }
  }

  Future<void> _sendWelcomeNotification(String userId) async {
    try {
      DocumentSnapshot configDoc = await _db.collection('settings').doc('app_config').get();
      if (configDoc.exists) {
        final config = configDoc.data() as Map<String, dynamic>;
        final welcomeTitle = config['welcomeNotifTitle'] ?? 'Welcome to ${AppConstants.appName}! 🎮';
        final welcomeMsg = config['welcomeNotifBody'] ?? config['welcomeMessage'] ?? 'Thanks for joining us!';

        if (welcomeMsg.isNotEmpty) {
          await _db.collection('notifications').add({
            'userId': userId,
            'title': welcomeTitle,
            'message': welcomeMsg,
            'dateTime': Timestamp.now(),
            'type': 'general',
          });
          
          await incrementUnreadCount(userId);
        }
      }
    } catch (e) {
      debugPrint("Error sending welcome notification: $e");
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint("Error sending password reset email: $e");
      rethrow;
    }
  }
}
