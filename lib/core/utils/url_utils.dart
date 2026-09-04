import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static Future<void> launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  static Future<void> sendEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Could not launch email to $email');
    }
  }
}
