import '../models/emergency_contact.dart';
import 'email_service.dart';

class EmergencyActionService {
  final EmailService _emailSvc;

  EmergencyActionService({EmailService? emailService})
      : _emailSvc = emailService ?? EmailService();

  /// Sends a REAL email via SMTP (mailer). Does NOT open any mail app.
  Future<void> email(
      EmergencyContact c, {
        required String subject,
        required String bodyHtml,
      }) async {
    final to = c.email?.trim();
    if (to == null || to.isEmpty) return;

    final ok = await _emailSvc.sendEmail(
      toEmails: [to],
      subject: subject,
      htmlBody: bodyHtml,
    );

    if (!ok) {
      throw StateError('SMTP email failed for: $to');
    }
  }

  /// Sends a REAL email to ALL contacts that have an email.
  Future<void> emailAll(
      List<EmergencyContact> contacts, {
        required String subject,
        required String bodyHtml,
      }) async {
    final toEmails = contacts
        .map((c) => c.email?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (toEmails.isEmpty) return;

    final ok = await _emailSvc.sendEmail(
      toEmails: toEmails,
      subject: subject,
      htmlBody: bodyHtml,
    );

    if (!ok) {
      throw StateError('SMTP emailAll failed');
    }
  }

  /// Emergency HTML template (so you don't need sendEmergencyAlert() in EmailService)
  String buildEmergencyHtml({
    required String alertType,
    required String details,
    DateTime? timestamp,
  }) {
    final t = timestamp ?? DateTime.now();
    final timeStr =
        '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #FF1744, #D50000); color: white; padding: 20px; border-radius: 10px 10px 0 0;">
    <h2 style="margin: 0;">🚨 ACİL DURUM UYARISI (SafeWear)</h2>
  </div>
  <div style="background: #f5f5f5; padding: 20px; border-radius: 0 0 10px 10px;">
    <table style="width: 100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Uyarı Tipi:</strong></td>
        <td style="padding: 10px; border-bottom: 1px solid #ddd;">$alertType</td>
      </tr>
      <tr>
        <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Detay:</strong></td>
        <td style="padding: 10px; border-bottom: 1px solid #ddd;">${details.replaceAll('\n', '<br>')}</td>
      </tr>
      <tr>
        <td style="padding: 10px;"><strong>Zaman:</strong></td>
        <td style="padding: 10px;">$timeStr</td>
      </tr>
    </table>

    <p style="color: #666; font-size: 12px; margin-top: 18px; text-align: center;">
      Bu mesaj SafeWear uygulaması tarafından otomatik olarak gönderilmiştir.
    </p>
  </div>
</div>
''';
  }

  /// Convenience: send emergency to all contacts
  Future<void> sendEmergencyAlertAll(
      List<EmergencyContact> contacts, {
        required String alertType,
        required String details,
        DateTime? timestamp,
      }) async {
    final html = buildEmergencyHtml(
      alertType: alertType,
      details: details,
      timestamp: timestamp,
    );

    await emailAll(
      contacts,
      subject: '🚨 ACİL DURUM: $alertType',
      bodyHtml: html,
    );
  }
}
