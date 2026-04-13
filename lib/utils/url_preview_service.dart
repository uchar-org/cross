import 'dart:convert';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:http/http.dart' as http;
import 'package:linkify/linkify.dart' as linkify_lib;
import 'package:matrix/matrix.dart';

class UrlPreviewData {
  final String? title;
  final String? description;
  final Uri? imageUri;
  final int? imageWidth;
  final int? imageHeight;
  final String? siteName;

  const UrlPreviewData({
    this.title,
    this.description,
    this.imageUri,
    this.imageWidth,
    this.imageHeight,
    this.siteName,
  });

  bool get hasContent =>
      title != null || description != null || imageUri != null;

  factory UrlPreviewData.fromJson(Map<String, Object?> json) {
    final imageUrl = json['og:image'] as String?;
    return UrlPreviewData(
      title: json['og:title'] as String?,
      description: json['og:description'] as String?,
      imageUri: imageUrl != null ? Uri.tryParse(imageUrl) : null,
      imageWidth: json['og:image:width'] as int?,
      imageHeight: json['og:image:height'] as int?,
      siteName: json['og:site_name'] as String?,
    );
  }

  @override
  String toString() =>
      'UrlPreviewData(title: $title, description: $description, image: $imageUri, site: $siteName)';
}

class UrlPreviewService {
  static final Map<String, UrlPreviewData?> _cache = {};

  static UrlPreviewData? getCached(String url) =>
      _cache.containsKey(url) ? _cache[url] : null;

  static bool isCached(String url) => _cache.containsKey(url);

  static Future<UrlPreviewData?> getPreview(Client client, String url) async {
    if (_cache.containsKey(url)) return _cache[url];

    final baseUri = client.baseUri;
    final bearerToken = client.bearerToken;
    if (baseUri == null || bearerToken == null) {
      Logs().w('URL preview: client not ready (baseUri=$baseUri, token=${bearerToken != null})');
      return null;
    }

    try {
      final endpoints = [
        '_matrix/client/v1/media/preview_url',
        '_matrix/media/v3/preview_url',
      ];

      for (final path in endpoints) {
        try {
          final requestUri = Uri(
            path: path,
            queryParameters: {'url': url},
          );

          final fullUri = baseUri.resolveUri(requestUri);
          Logs().d('URL preview: trying $fullUri');

          final request = http.Request('GET', fullUri);
          request.headers['authorization'] = 'Bearer $bearerToken';

          final response = await client.httpClient.send(request);
          final responseBody = await response.stream.toBytes();

          if (response.statusCode != 200) {
            Logs().w('URL preview: $path returned ${response.statusCode}');
            continue;
          }

          final responseString = utf8.decode(responseBody);
          final json = jsonDecode(responseString) as Map<String, Object?>;
          Logs().d('URL preview: response for $url: $json');
          final data = UrlPreviewData.fromJson(json);

          _cache[url] = data.hasContent ? data : null;
          return _cache[url];
        } catch (e) {
          Logs().d('URL preview: $path failed, trying next', e);
          continue;
        }
      }

      _cache[url] = null;
      return null;
    } catch (e, s) {
      Logs().w('URL preview: failed for $url', e, s);
      _cache[url] = null;
      return null;
    }
  }

  static List<String> extractUrls(String text) {
    final elements = linkify_lib.linkify(
      text,
      options: const LinkifyOptions(
        looseUrl: true,
        defaultToHttps: true,
      ),
    );
    return elements
        .whereType<linkify_lib.UrlElement>()
        .map((e) => e.url)
        .toSet()
        .toList();
  }
}
