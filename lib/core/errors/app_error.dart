import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns any exception into a message safe to show to normal users.
/// Raw Supabase/internal errors are never exposed.
String friendlyError(Object error) {
  final raw = '${error.runtimeType} $error'.toLowerCase();
  final offline = raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('xmlhttprequest') ||
      raw.contains('retryable') ||
      raw.contains('network');
  if (offline) {
    return 'Cannot reach the server. Check your internet connection and try again.';
  }

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if ('${error.statusCode}' == '429' || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (msg.contains('not confirmed')) {
      return 'This account is not confirmed yet. Please contact the club president.';
    }
    if (msg.contains('invalid')) return 'Incorrect email or password.';
    return 'Sign-in failed. Please try again.';
  }

  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'You do not have permission to do that.';
    }
    // P0001 = our own validation messages raised in database triggers.
    if (error.code == 'P0001') return error.message;
    return 'The server could not complete that request. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}
