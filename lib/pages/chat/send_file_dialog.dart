import 'package:async/async.dart' show Result;
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cross_file/cross_file.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:fluffychat/utils/other_party_can_receive.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/size_string.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:mime/mime.dart';

import '../../utils/resize_video.dart';

class SendFileDialog extends StatefulWidget {
  final Room room;
  final List<XFile> files;
  final BuildContext outerContext;
  final String? threadLastEventId, threadRootEventId;

  const SendFileDialog({
    required this.room,
    required this.files,
    required this.outerContext,
    required this.threadLastEventId,
    required this.threadRootEventId,
    super.key,
  });

  @override
  SendFileDialogState createState() => SendFileDialogState();
}

class SendFileDialogState extends State<SendFileDialog> {
  bool compress = true;

  /// Images smaller than 20kb don't need compression.
  static const int minSizeToCompress = 20 * 1000;

  final TextEditingController _labelTextController = TextEditingController();

  Future<void> _send() async {
    final scaffoldMessenger = ScaffoldMessenger.of(widget.outerContext);
    final l10n = L10n.of(context);

    try {
      if (!widget.room.otherPartyCanReceiveMessages) {
        throw OtherPartyCanNotReceiveMessages();
      }
      scaffoldMessenger.showLoadingSnackBar(l10n.prepareSendingAttachment);
      Navigator.of(context, rootNavigator: false).pop();
      final clientConfig = await Result.capture(widget.room.client.getConfig());
      final maxUploadSize =
          clientConfig.asValue?.value.mUploadSize ?? 100 * 1000 * 1000;

      for (final xfile in widget.files) {
        final MatrixFile file;
        MatrixImageFile? thumbnail;
        final length = await xfile.length();
        final mimeType = xfile.mimeType ?? lookupMimeType(xfile.path);

        // Generate video thumbnail
        if (PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video')) {
          scaffoldMessenger.showLoadingSnackBar(l10n.generatingVideoThumbnail);
          thumbnail = await xfile.getVideoThumbnail();
        }

        // If file is a video, shrink it!
        if (PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video')) {
          scaffoldMessenger.showLoadingSnackBar(l10n.compressVideo);
          file = await xfile.getVideoInfo(
            compress: length > minSizeToCompress && compress,
          );
        } else {
          if (length > maxUploadSize) {
            throw FileTooBigMatrixException(length, maxUploadSize);
          }
          // Else we just create a MatrixFile
          file = MatrixFile(
            bytes: await xfile.readAsBytes(),
            name: xfile.name,
            mimeType: mimeType,
          ).detectFileType;
        }

        if (file.bytes.length > maxUploadSize) {
          throw FileTooBigMatrixException(length, maxUploadSize);
        }

        if (widget.files.length > 1) {
          scaffoldMessenger.showLoadingSnackBar(
            l10n.sendingAttachmentCountOfCount(
              widget.files.indexOf(xfile) + 1,
              widget.files.length,
            ),
          );
        }

        final label = _labelTextController.text.trim();

        try {
          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? 1600 : null,
            extraContent: label.isEmpty ? null : {'body': label},
            threadRootEventId: widget.threadRootEventId,
            threadLastEventId: widget.threadLastEventId,
          );
        } on MatrixException catch (e) {
          final retryAfterMs = e.retryAfterMs;
          if (e.error != MatrixError.M_LIMIT_EXCEEDED || retryAfterMs == null) {
            rethrow;
          }
          final retryAfterDuration = Duration(
            milliseconds: retryAfterMs + 1000,
          );

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.serverLimitReached(retryAfterDuration.inSeconds),
              ),
            ),
          );
          await Future.delayed(retryAfterDuration);

          scaffoldMessenger.showLoadingSnackBar(l10n.sendingAttachment);

          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? 1600 : null,
            extraContent: label.isEmpty ? null : {'body': label},
          );
        }
      }
      scaffoldMessenger.clearSnackBars();
    } catch (e) {
      scaffoldMessenger.clearSnackBars();
      final theme = Theme.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: theme.colorScheme.errorContainer,
          closeIconColor: theme.colorScheme.onErrorContainer,
          content: Text(
            e.toLocalizedString(widget.outerContext),
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          duration: const Duration(seconds: 30),
          showCloseIcon: true,
        ),
      );
      rethrow;
    }

    return;
  }

  Future<String> _calcCombinedFileSize() async {
    final lengths = await Future.wait(
      widget.files.map((file) => file.length()),
    );
    return lengths.fold<double>(0, (p, length) => p + length).sizeString;
  }

  Widget _buildSingleImagePreview(XFile file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
      child: FutureBuilder<List<int>>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const SizedBox(
              width: 220,
              height: 220,
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (snapshot.hasError) {
            return const SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            );
          }
          return Image.memory(
            snapshot.data! as dynamic,
            height: 220,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final count = widget.files.length;
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width > 400 ? 360.0 : size.width * 0.85);
    final maxGridHeight = size.height * 0.45;

    final crossAxisCount = count <= 2 ? 2 : 3;
    final spacing = 6.0;
    final cellSize =
        (dialogWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final rowCount = (count / crossAxisCount).ceil();
    final gridHeight = (cellSize * rowCount + spacing * (rowCount - 1))
        .clamp(0.0, maxGridHeight);

    return SizedBox(
      height: gridHeight,
      width: dialogWidth,
      child: GridView.builder(
        physics: gridHeight >= maxGridHeight
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return FutureBuilder<List<int>>(
            future: widget.files[index].readAsBytes(),
            builder: (context, snapshot) {
              return ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConfig.borderRadius / 2),
                child: snapshot.data != null
                    ? GestureDetector(
                      onTap: () {
                        ProfessionalImagePreview.show(
                          context,
                          bytes: snapshot.data as dynamic,
                          heroTag: widget.key.toString(),
                        );
                      },
                      child: Hero(
                        tag: widget.key.toString(),
                        child: Image.memory(
                            snapshot.data! as dynamic,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.broken_image_outlined,
                              ),
                            ),
                          ),
                      ),
                    )
                    : snapshot.hasError
                        ? Container(
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.broken_image_outlined,
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var sendStr = L10n.of(context).sendFile;
    final uniqueFileType = widget.files
        .map((file) => file.mimeType ?? lookupMimeType(file.name))
        .map((mimeType) => mimeType?.split('/').first)
        .toSet()
        .singleOrNull;

    final fileName = widget.files.length == 1
        ? widget.files.single.name
        : L10n.of(context).countFiles(widget.files.length);
    final fileTypes = widget.files
        .map((file) => file.name.split('.').last)
        .toSet()
        .join(', ')
        .toUpperCase();

    if (uniqueFileType == 'image') {
      if (widget.files.length == 1) {
        sendStr = L10n.of(context).sendImage;
      } else {
        sendStr = L10n.of(context).sendImages(widget.files.length);
      }
    } else if (uniqueFileType == 'audio') {
      sendStr = L10n.of(context).sendAudio;
    } else if (uniqueFileType == 'video') {
      sendStr = L10n.of(context).sendVideo;
    }

    final compressionSupported =
        uniqueFileType != 'video' || PlatformInfos.isMobile;

    return FutureBuilder<String>(
      future: _calcCombinedFileSize(),
      builder: (context, snapshot) {
        final sizeString =
            snapshot.data ?? L10n.of(context).calculatingFileSize;

        return AlertDialog.adaptive(
          title: Text(sendStr),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                children: [
                  const SizedBox(height: 12),
                  if (uniqueFileType == 'image')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: widget.files.length == 1
                          ? Center(
                              child:
                                  _buildSingleImagePreview(widget.files.first),
                            )
                          : _buildImageGrid(context),
                    ),

                  // ── BOSHQA FAYL PREVIEW ──
                  if (uniqueFileType != 'image')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            uniqueFileType == null
                                ? Icons.description_outlined
                                : uniqueFileType == 'video'
                                ? Icons.video_file_outlined
                                : uniqueFileType == 'audio'
                                ? Icons.audio_file_outlined
                                : Icons.description_outlined,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: .min,
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$sizeString - $fileTypes',
                                  style: theme.textTheme.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.files.length == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: DialogTextField(
                        controller: _labelTextController,
                        labelText: L10n.of(context).optionalMessage,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 255,
                        counterText: '',
                      ),
                    ),
                  // Workaround for SwitchListTile.adaptive crashes in CupertinoDialog
                  if ({'image', 'video'}.contains(uniqueFileType))
                    Row(
                      crossAxisAlignment: .center,
                      children: [
                        if ({
                          TargetPlatform.iOS,
                          TargetPlatform.macOS,
                        }.contains(theme.platform))
                          CupertinoSwitch(
                            value: compressionSupported && compress,
                            onChanged: compressionSupported
                                ? (v) => setState(() => compress = v)
                                : null,
                          )
                        else
                          Switch.adaptive(
                            value: compressionSupported && compress,
                            onChanged: compressionSupported
                                ? (v) => setState(() => compress = v)
                                : null,
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .start,
                            children: [
                              Text(
                                L10n.of(context).compress,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (!compress)
                                Text(
                                  ' ($sizeString)',
                                  style: theme.textTheme.labelSmall,
                                ),
                              if (!compressionSupported)
                                Text(
                                  L10n.of(context).notSupportedOnThisDevice,
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            AdaptiveDialogAction(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: false).pop(),
              child: Text(L10n.of(context).cancel),
            ),
            AdaptiveDialogAction(
              onPressed: _send,
              child: Text(L10n.of(context).send),
            ),
          ],
        );
      },
    );
  }
}

extension on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoadingSnackBar(
    String title,
  ) {
    clearSnackBars();
    return showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        dismissDirection: DismissDirection.none,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class ProfessionalImagePreview extends StatefulWidget {
  final Uint8List bytes;
  final String heroTag;

  const ProfessionalImagePreview({
    super.key,
    required this.bytes,
    required this.heroTag,
  });

  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    required String heroTag,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => ProfessionalImagePreview(
        bytes: bytes,
        heroTag: heroTag,
      ),
    );
  }

  @override
  State<ProfessionalImagePreview> createState() =>
      _ProfessionalImagePreviewState();
}

class _ProfessionalImagePreviewState extends State<ProfessionalImagePreview> {
  final TransformationController _controller = TransformationController();

  double _scale = 1;

  void _handleDoubleTap() {
    if (_scale > 1) {
      _controller.value = Matrix4.identity();
      _scale = 1;
    } else {
      _controller.value = Matrix4.identity()..scale(2.5);
      _scale = 2.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > 300) {
          Navigator.pop(context);
        }
      },
      onDoubleTap: _handleDoubleTap,
      child: Material(
        color: Colors.black,
        child: Center(
          child: Hero(
            tag: widget.heroTag,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 5,
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}