import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/data/models/transaction_model.dart';
import 'package:ff_arena/data/datasources/auth_service.dart';
import 'package:ff_arena/core/utils/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _userModel;
  bool _isLoading = false;
  bool _isReady = false;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _userSubscription;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;

  Stream<List<TransactionModel>> get transactions => _authService.getTransactions(_userModel?.uid ?? '');
  Stream<List<UserModel>> get topEarners => _authService.getTopEarners();
  Stream<List<UserModel>> get allUsers => _authService.getAllUsers();

  Future<void> clearUserTransactions(String userId) async {
    await _authService.clearUserTransactions(userId);
    notifyListeners();
  }

  AuthProvider() {
    _init();
  }

  void _init() async {
    // Check if there is an initial cached user immediately
    final User? initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null) {
      debugPrint("Startup: Initial user found: ${initialUser.uid}");
      await _refreshUserModel(initialUser.uid);
    } else {
      // If currentUser is null, wait a brief moment to see if authStateChanges emits a user.
      // Sometimes on cold starts, FirebaseAuth takes a frame to load the cached token.
      debugPrint("Startup: No immediate user found, waiting for auth state confirmation...");
      try {
        final User? streamUser = await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );
        if (streamUser != null) {
          debugPrint("Startup: User resolved from stream: ${streamUser.uid}");
          await _refreshUserModel(streamUser.uid);
        } else {
          debugPrint("Startup: No user resolved from stream");
          _isReady = true;
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Startup: Error awaiting auth state: $e");
        _isReady = true;
        notifyListeners();
      }
    }

    // After resolving the initial state, listen for subsequent auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().skip(1).listen((User? user) async {
      debugPrint("Auth state changed (subsequent): ${user?.uid}");
      if (user != null) {
        if (_userModel == null || _userModel?.uid != user.uid) {
          await _refreshUserModel(user.uid);
        }
      } else {
        _userSubscription?.cancel();
        _userModel = null;
        _isReady = true;
        notifyListeners();
      }
    });
  }

  Future<void> _refreshUserModel(String uid) async {
    try {
      final model = await _authService.getUserData(uid);
      if (model != null) {
        _userModel = model;
        _setupUserStream(uid);
      } else {
        debugPrint("User data not found in Firestore for $uid");
        // If Firestore doc doesn't exist, we might still be "ready" but with null model
        // This could happen if a user is in Auth but not in Firestore yet
        _userModel = null;
      }
    } catch (e) {
      debugPrint("Error fetching initial user data: $e");
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  void _setupUserStream(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _authService.userStream(uid).listen((model) {
      _userModel = model;
      _isReady = true;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error in userStream: $e");
      _isReady = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<String?> signUpWithEmail(String email, String password, String name, {String? phone, String? ffUid, String? referralCode}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signUpWithEmail(email, password, name, phone: phone, ffUid: ffUid, referralCode: referralCode);
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      switch (e.code) {
        case 'email-already-in-use': return "This email is already registered.";
        case 'weak-password': return "Password is too weak. Please use a stronger password.";
        case 'invalid-email': return "Invalid email format.";
        default: return e.message ?? "Registration failed. Try again.";
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString().replaceAll("Exception: ", "");
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Login Error Code: ${e.code}");
      switch (e.code) {
        case 'user-not-found': return "This email is not registered.";
        case 'wrong-password': return "Incorrect password. Please try again.";
        case 'invalid-credential': return "Incorrect email or password.";
        case 'user-disabled': return "Your account has been blocked. Please contact support.";
        case 'too-many-requests': return "Too many failed attempts. Please try again later.";
        case 'invalid-email': return "Invalid email format.";
        default: return "Login failed: ${e.message}";
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential? credential = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return credential != null ? null : "Sign in cancelled";
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> deposit(double amount) async {
    if (_userModel == null) return;
    await _authService.deposit(_userModel!.uid, amount);
    await refreshUser();
  }

  Future<void> adminUpdateUser(String uid, Map<String, dynamic> data) async {
    await _authService.adminUpdateUser(uid, data);
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data, {File? imageFile}) async {
    if (_userModel == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      if (imageFile != null) {
        final storageService = StorageService();
        String? imageUrl = await storageService.uploadImage('profiles', imageFile);
        if (imageUrl != null) {
          data['profilePic'] = imageUrl;
        }
      }
      
      await _authService.updateUserProfile(_userModel!.uid, data);
      _userModel = await _authService.getUserData(_userModel!.uid);
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetUnreadCount() async {
    if (_userModel != null) {
      await _authService.resetUnreadCount(_userModel!.uid);
      notifyListeners();
    }
  }

  Future<void> adminIncrementUnreadCount(String uid) async {
    await _authService.incrementUnreadCount(uid);
  }

  Future<void> adminIncrementAllUsersUnreadCount() async {
    await _authService.incrementAllUsersUnreadCount();
  }

  Future<void> refreshUser() async {
    if (_userModel == null) return;
    _userModel = await _authService.getUserData(_userModel!.uid);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
