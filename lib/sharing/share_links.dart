/// The permanent Firebase Hosting /go/ URL, not a store listing.
/// Store destinations live only in hosting/public/store-links.js.
class ShareLinks {
  const ShareLinks._();

  static const brainRushLandingUrl =
      'https://brain-rush-almobairik.web.app/go/';

  static String? get shareUrl {
    final raw = brainRushLandingUrl;
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? raw
        : null;
  }
}
