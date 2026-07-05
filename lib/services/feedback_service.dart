import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  static final _db = Supabase.instance.client;

  static Future<String?> logResponse({
    required String userId,
    required String mode, // 'guru' or 'scholar'
    required String language,
    required String question,
    required String response,
  }) async {
    try {
      final row = await _db.from('ai_feedback').insert({
        'user_id': userId,
        'mode': mode,
        'language': language,
        'question': question,
        'response': response,
      }).select('id').single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateRating(String feedbackId, int rating) async {
    try {
      await _db.from('ai_feedback').update({'rating': rating}).eq('id', feedbackId);
    } catch (_) {}
  }
}
