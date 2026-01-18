import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // ⚠️ Not recommended to hardcode in production (easy to extract from APK/IPA)
  // But works for quick prototype / demo.
  static const String defaultSenderEmail = 'safewear.alerts@gmail.com';
  static const String defaultAppPassword = 'hudw ajiv aeih resj'; // app password

  String? _senderEmail;
  String? _appPassword;
  SmtpServer? _smtpServer;

  EmailService() {
    configureSender(
      email: defaultSenderEmail,
      appPassword: defaultAppPassword,
    );
  }

  bool get isConfigured =>
      _senderEmail != null &&
          _appPassword != null &&
          _smtpServer != null;

  void configureSender({
    required String email,
    required String appPassword,
  }) {
    _senderEmail = email.trim();
    _appPassword = appPassword.trim();
    _smtpServer = gmail(_senderEmail!, _appPassword!);

    debugPrint('[EmailService] Sender configured: $_senderEmail');
  }

  Future<bool> sendEmail({
    required List<String> toEmails,
    required String subject,
    required String htmlBody,
    String senderName = 'SafeWear',
  }) async {
    if (!isConfigured) {
      debugPrint('[EmailService] Not configured');
      return false;
    }

    final cleaned = toEmails
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (cleaned.isEmpty) {
      debugPrint('[EmailService] No recipients');
      return false;
    }

    try {
      final message = Message()
        ..from = Address(_senderEmail!, senderName)
        ..recipients.addAll(cleaned)
        ..subject = subject
        ..html = htmlBody;

      final report = await send(message, _smtpServer!);
      debugPrint('[EmailService] ✅ Sent: $report');
      return true;
    } catch (e) {
      debugPrint('[EmailService] ❌ Error: $e');
      return false;
    }
  }

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
  <div style="background: #D50000; color: white; padding: 16px; border-radius: 10px 10px 0 0;">
    <h2 style="margin:0;">🚨 SafeWear Emergency Alert</h2>
  </div>
  <div style="background: #f5f5f5; padding: 16px; border-radius: 0 0 10px 10px;">
    <table style="width:100%; border-collapse: collapse;">
      <tr>
        <td style="padding: 8px; border-bottom: 1px solid #ddd;"><b>Type</b></td>
        <td style="padding: 8px; border-bottom: 1px solid #ddd;">$alertType</td>
      </tr>
      <tr>
        <td style="padding: 8px; border-bottom: 1px solid #ddd;"><b>Details</b></td>
        <td style="padding: 8px; border-bottom: 1px solid #ddd;">$details</td>
      </tr>
      <tr>
        <td style="padding: 8px;"><b>Time</b></td>
        <td style="padding: 8px;">$timeStr</td>
      </tr>
    </table>
    <p style="color:#666; font-size: 12px; margin-top:16px; text-align:center;">
      This email was automatically sent by SafeWear.
    </p>
  </div>
</div>
''';
  }
}
