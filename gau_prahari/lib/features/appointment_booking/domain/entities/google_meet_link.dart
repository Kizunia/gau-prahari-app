/// Validation helpers for the shared Google Meet link a veterinarian uses for
/// their appointments.
class GoogleMeetLink {
  const GoogleMeetLink._();

  /// Returns a normalized URL, an empty string when clearing the link, or null
  /// when the supplied value is not a Google Meet URL.
  static String? normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'meet.google.com' ||
        uri.pathSegments.isEmpty) {
      return null;
    }

    return uri.toString();
  }
}
