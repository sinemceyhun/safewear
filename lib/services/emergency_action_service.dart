import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';

class EmergencyActionService {
  Future<void> call(EmergencyContact c) async {
    final phone = c.phone?.trim();
    if (phone == null || phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    await _launch(uri);
  }

  /// Opens SMS app with pre-filled message (user can review and send manually)
  /// Note: For safety, SMS is not sent automatically. User must confirm.
  Future<void> sms(EmergencyContact c, String message) async {
    final phone = c.phone?.trim();
    if (phone == null || phone.isEmpty) return;

    // Open SMS app with pre-filled message
    // User must manually press send button (safer approach)
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    await _launch(uri);
  }

  Future<void> email(
      EmergencyContact c, {
        required String subject,
        required String body,
      }) async {
    final email = c.email?.trim();
    if (email == null || email.isEmpty) return;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject, 'body': body},
    );
    await _launch(uri);
  }

  Future<void> _launch(Uri uri) async {
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      throw StateError('Cannot launch: $uri');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
