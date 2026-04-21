import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/image_viewer/image_viewer.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
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
    final displayEvent =
        timeline != null ? replyEvent.getDisplayEvent(timeline) : replyEvent;
    final fontSize =
        AppConfig.messageFontSize * AppSettings.fontSizeFactor.value;
    final color = theme.brightness == Brightness.dark
        ? theme.colorScheme.onTertiaryContainer
        : ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    final textColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : ownMessage
        ? theme.colorScheme.onTertiary
        : theme.colorScheme.onSurface;

    final msgType = displayEvent.messageType;
    final isImage = msgType == MessageTypes.Image;
    final isVideo = msgType == MessageTypes.Video;
    final isFile = msgType == MessageTypes.File;
    final isAudio = msgType == MessageTypes.Audio;
    final isMedia = isImage || isVideo;

    final bodyText = (isMedia || isFile || isAudio)
        ? displayEvent.body
        : displayEvent.calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: false,
            hideReply: true,
            plaintextBody: true,
          );

    final thumbnailSize = fontSize * 1.4 + 16;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: thumbnailSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConfig.borderRadius),
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          if (isMedia)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => ImageViewer(
                    displayEvent,
                    timeline: timeline,
                    outerContext: context,
                  ),
                ),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: MxcImage(
                  event: displayEvent,
                  width: thumbnailSize,
                  height: thumbnailSize,
                  fit: BoxFit.cover,
                  isThumbnail: true,
                ),
              ),
            ),
          )
          else if (isFile || isAudio)
            Icon(
              isAudio ? Icons.mic : Icons.attach_file,
              size: thumbnailSize * 0.6,
              color: color,
            ),
          if (isMedia || isFile || isAudio) const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FutureBuilder<User?>(
                  initialData: displayEvent.senderFromMemoryOrFallback,
                  future: displayEvent.fetchSenderUser(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data?.calcDisplayname() ??
                          displayEvent
                              .senderFromMemoryOrFallback
                              .calcDisplayname(),
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
                  bodyText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: textColor,
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
