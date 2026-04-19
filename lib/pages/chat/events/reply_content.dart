import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/url_preview_service.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../../config/app_config.dart';

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool ownMessage;
  final Timeline? timeline;

  const ReplyContent(
    this.replyEvent, {
    this.ownMessage = false,
    super.key,
    this.timeline,
  });

  static const BorderRadius borderRadius = BorderRadius.only(
    topRight: Radius.circular(AppConfig.borderRadius / 2),
    bottomRight: Radius.circular(AppConfig.borderRadius / 2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final timeline = this.timeline;
    final displayEvent = timeline != null
        ? replyEvent.getDisplayEvent(timeline)
        : replyEvent;
    final fontSize =
        AppConfig.messageFontSize * AppSettings.fontSizeFactor.value;
    final color = theme.brightness == Brightness.dark
        ? theme.colorScheme.onTertiaryContainer
        : ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    final urls = UrlPreviewService.extractUrls(displayEvent.body);
    final thumbSize = fontSize * 2 + 16;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: Row(
        mainAxisSize: .min,
        children: <Widget>[
          Container(
            width: 5,
            height: thumbSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConfig.borderRadius),
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          if (urls.isNotEmpty)
            _ReplyUrlPreviewThumb(url: urls.first, size: thumbSize),
          Flexible(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisAlignment: .center,
              children: <Widget>[
                FutureBuilder<User?>(
                  initialData: displayEvent.senderFromMemoryOrFallback,
                  future: displayEvent.fetchSenderUser(),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.calcDisplayname() ?? displayEvent.senderFromMemoryOrFallback.calcDisplayname()}:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: fontSize,
                      ),
                    );
                  },
                ),
                Text(
                  displayEvent.calcLocalizedBodyFallback(
                    MatrixLocals(L10n.of(context)),
                    withSenderNamePrefix: false,
                    hideReply: true,
                    plaintextBody: true,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.onSurface
                        : ownMessage
                        ? theme.colorScheme.onTertiary
                        : theme.colorScheme.onSurface,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _ReplyUrlPreviewThumb extends StatefulWidget {
  final String url;
  final double size;

  const _ReplyUrlPreviewThumb({required this.url, required this.size});

  @override
  State<_ReplyUrlPreviewThumb> createState() => _ReplyUrlPreviewThumbState();
}

class _ReplyUrlPreviewThumbState extends State<_ReplyUrlPreviewThumb> {
  UrlPreviewData? _data;
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    if (UrlPreviewService.isCached(widget.url)) {
      _data = UrlPreviewService.getCached(widget.url);
      _didLoad = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final client = Matrix.of(context).client;
      final data = await UrlPreviewService.getPreview(client, widget.url);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {}
  }

  bool _isImageSuitable(UrlPreviewData data) {
    final w = data.imageWidth;
    final h = data.imageHeight;
    if (w != null && w < 64) return false;
    if (h != null && h < 64) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final imageUri = data?.imageUri;
    if (data == null || imageUri == null || !_isImageSuitable(data)) {
      return const SizedBox.shrink();
    }

    final size = widget.size;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size,
          height: size,
          child: imageUri.scheme == 'mxc'
              ? MxcImage(
                  uri: imageUri,
                  fit: BoxFit.cover,
                  isThumbnail: true,
                  width: size,
                  height: size,
                  cacheKey: imageUri.toString(),
                  placeholder: (_) => SizedBox(width: size, height: size),
                )
              : Image.network(
                  imageUri.toString(),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}
