import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ff_arena/data/models/user_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createUserProfile(UserModel user) async {
    final Map<String, dynamic> data = {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'ff_uid': user.ffUid,
      'profile_pic': user.profilePic,
      'balance': user.balance,
      'bonus_balance': user.bonusBalance,
      'total_wins': user.totalWins,
      'total_earnings': user.totalEarnings,
      'referral_code': user.referralCode,
      'referred_by': user.referredBy,
      'is_admin': user.isAdmin,
      'is_blocked': user.isBlocked,
      'is_highlighted': user.isHighlighted,
      'leaderboard_priority': user.leaderboardPriority,
      'unread_notifications': user.unreadNotifications,
      'device_id': user.deviceId,
      'created_at': user.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    await _client.from('users').upsert(data);
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle();
      
      if (response != null) {
        return _fromSupabaseMap(response);
      }
      return null;
    } catch (e) {
      print("Supabase getUserData error: $e");
      return null;
    }
  }

  UserModel _fromSupabaseMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'],
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      ffUid: data['ff_uid'],
      profilePic: data['profile_pic'],
      balance: (data['balance'] ?? 0.0).toDouble(),
      bonusBalance: (data['bonus_balance'] ?? 0.0).toDouble(),
      totalWins: data['total_wins'] ?? 0,
      totalEarnings: (data['total_earnings'] ?? 0.0).toDouble(),
      referralCode: data['referral_code'],
      referredBy: data['referred_by'],
      isAdmin: data['is_admin'] ?? false,
      isBlocked: data['is_blocked'] ?? false,
      isHighlighted: data['is_highlighted'] ?? false,
      leaderboardPriority: data['leaderboard_priority'] ?? 0,
      unreadNotifications: data['unread_notifications'] ?? 0,
      deviceId: data['device_id'],
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
    );
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    // Convert keys to snake_case if they exist in the input data
    final Map<String, dynamic> supabaseData = {};
    data.forEach((key, value) {
      if (key == 'ffUid') supabaseData['ff_uid'] = value;
      else if (key == 'profilePic') supabaseData['profile_pic'] = value;
      else if (key == 'bonusBalance') supabaseData['bonus_balance'] = value;
      else if (key == 'totalWins') supabaseData['total_wins'] = value;
      else if (key == 'totalEarnings') supabaseData['total_earnings'] = value;
      else if (key == 'referralCode') supabaseData['referral_code'] = value;
      else if (key == 'referredBy') supabaseData['referred_by'] = value;
      else if (key == 'isAdmin') supabaseData['is_admin'] = value;
      else if (key == 'isBlocked') supabaseData['is_blocked'] = value;
      else if (key == 'isHighlighted') supabaseData['is_highlighted'] = value;
      else if (key == 'leaderboardPriority') supabaseData['leaderboard_priority'] = value;
      else if (key == 'unreadNotifications') supabaseData['unread_notifications'] = value;
      else if (key == 'deviceId') supabaseData['device_id'] = value;
      else if (key == 'createdAt') supabaseData['created_at'] = value;
      else supabaseData[key] = value;
    });

    await _client.from('users').update(supabaseData).eq('uid', uid);
  }

  Future<bool> checkDeviceLimit(String deviceId) async {
    final response = await _client
        .from('users')
        .select('uid')
        .eq('device_id', deviceId);
    
    return (response as List).length < 2;
  }

  // AI Chat Persistence
  Future<void> saveAIMessage(String userId, String text, bool isUser) async {
    await _client.from('ai_chat_messages').insert({
      'user_id': userId,
      'text': text,
      'is_user': isUser,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAIChatHistory(String userId) async {
    final response = await _client
        .from('ai_chat_messages')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
