import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/url_preview_service.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UrlPreviewWidget extends StatefulWidget {
  final String url;
  final Color textColor;
  final Color linkColor;

  const UrlPreviewWidget({
    super.key,
    required this.url,
    required this.textColor,
    required this.linkColor,
  });

  @override
  State<UrlPreviewWidget> createState() => _UrlPreviewWidgetState();
}

class _UrlPreviewWidgetState extends State<UrlPreviewWidget>
    with AutomaticKeepAliveClientMixin {
  UrlPreviewData? _previewData;
  bool _loaded = false;
  bool _didLoad = false;
  bool _imageLoadFailed = false;

  @override
  bool get wantKeepAlive => _previewData != null;

  static final _youtubeVideoRegex = RegExp(
    r'(?:youtube\.com/watch|youtu\.be/|youtube\.com/embed/|youtube\.com/shorts/)',
    caseSensitive: false,
  );

  bool get _isYoutubeVideo => _youtubeVideoRegex.hasMatch(widget.url);

  @override
  void initState() {
    super.initState();
    // for cashe
    if (UrlPreviewService.isCached(widget.url)) {
      _previewData = UrlPreviewService.getCached(widget.url);
      _loaded = true;
      _didLoad = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    try {
      final client = Matrix.of(context).client;
      final data = await UrlPreviewService.getPreview(client, widget.url);
      if (!mounted) return;
      setState(() {
        _previewData = data;
        _loaded = true;
      });
    } catch (e, s) {
      Logs().d('URL preview widget error', e, s);
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  static const double _minImageDimension = 64;

  bool _hasSuitableImage(UrlPreviewData data) {
    final w = data.imageWidth;
    final h = data.imageHeight;
    if (w != null && w < _minImageDimension) return false;
    if (h != null && h < _minImageDimension) return false;
    return true;
  }

  Widget _buildMxcImage(Uri uri, double width, double height, BoxFit fit) {
    return MxcImage(
      uri: uri,
      fit: fit,
      isThumbnail: true,
      width: width,
      height: height,
      cacheKey: uri.toString(),
      placeholder: (_) => SizedBox(width: width, height: height),
    );
  }

  Widget _buildNetworkImage(Uri uri, double width, double height, BoxFit fit) {
    return Image.network(
      uri.toString(),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_imageLoadFailed) {
            setState(() => _imageLoadFailed = true);
          }
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTextContent(UrlPreviewData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.siteName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              data.siteName!,
              style: TextStyle(
                color: widget.linkColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (data.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              data.title!,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (data.description != null)
          Text(
            data.description!,
            style: TextStyle(
              color: widget.textColor.withAlpha(180),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_loaded || _previewData == null) return const SizedBox.shrink();

    final data = _previewData!;
    final theme = Theme.of(context);
    final showImage =
        data.imageUri != null && !_imageLoadFailed && _hasSuitableImage(data);
    final isYoutube = _isYoutubeVideo;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return GestureDetector(
          onTap: () => launchUrlString(
            widget.url,
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            width: availableWidth,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(AppConfig.borderRadius - 4),
            ),
            clipBehavior: Clip.antiAlias,
            child: isYoutube && showImage
                ? _buildYoutubeLayout(data, availableWidth)
                : _buildCompactLayout(data, showImage, availableWidth),
          ),
        );
      },
    );
  }

  Widget _buildYoutubeLayout(UrlPreviewData data, double width) {
    final imageUri = data.imageUri!;
    const imgPadding = 8.0;
    final imgWidth = width - imgPadding * 2;
    final thumbHeight = (imgWidth * 9 / 16).clamp(120.0, 220.0);
    const imgRadius = BorderRadius.all(Radius.circular(8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: imgPadding,
            right: imgPadding,
            top: imgPadding,
          ),
          child: ClipRRect(
            borderRadius: imgRadius,
            child: SizedBox(
              width: imgWidth,
              height: thumbHeight,
              child: imageUri.scheme == 'mxc'
                  ? _buildMxcImage(imageUri, imgWidth, thumbHeight, BoxFit.cover)
                  : _buildNetworkImage(imageUri, imgWidth, thumbHeight, BoxFit.cover),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: _buildTextContent(data),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(
    UrlPreviewData data,
    bool showImage,
    double width,
  ) {
    if (showImage) {
      final imageUri = data.imageUri!;
      const imgRadius = BorderRadius.all(Radius.circular(6));
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: imgRadius,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: imageUri.scheme == 'mxc'
                        ? _buildMxcImage(imageUri, 52, 52, BoxFit.cover)
                        : _buildNetworkImage(imageUri, 52, 52, BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildTextContent(data)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: _buildTextContent(data),
      ),
    );
  }
}
