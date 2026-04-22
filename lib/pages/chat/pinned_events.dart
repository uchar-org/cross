import 'dart:async';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_app_bar_list_tile.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:matrix/matrix.dart';

class PinnedEvents extends StatelessWidget {
  final ChatController controller;

  const PinnedEvents(this.controller, {super.key});

  Future<void> _displayPinnedEventsDialog(BuildContext context) async {
    final l10n = L10n.of(context);
    final eventsResult = await showFutureLoadingDialog(
      context: context,
      future: () => Future.wait(
        controller.room.pinnedEventIds.map(
          (eventId) => controller.room.getEventById(eventId),
        ),
      ),
    );
    final events = eventsResult.result;
    if (events == null) return;
    if (!context.mounted) return;

    final eventId = events.length == 1
        ? events.single?.eventId
        : await showModalActionPopup<String>(
            context: context,
            title: l10n.pin,
            cancelLabel: l10n.cancel,
            actions: events
                .map(
                  (event) => AdaptiveModalAction(
                    value: event?.eventId ?? '',
                    icon: const Icon(TablerIcons.pin),
                    label:
                        event?.calcLocalizedBodyFallback(
                          MatrixLocals(l10n),
                          withSenderNamePrefix: true,
                          hideReply: true,
                        ) ??
                        'UNKNOWN',
                  ),
                )
                .toList(),
          );

    if (eventId != null) controller.scrollToEventId(eventId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pinnedEventIds = controller.room.pinnedEventIds;

    if (pinnedEventIds.isEmpty || controller.activeThreadId != null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Event?>(
      future: controller.room.getEventById(pinnedEventIds.last),
      builder: (context, snapshot) {
        final event = snapshot.data;
        final msgType = event?.messageType;
        final isImage = msgType == MessageTypes.Image;
        final isVideo = msgType == MessageTypes.Video;
        final isMedia = event != null && (isImage || isVideo);

        final pinButton = IconButton(
          splashRadius: 18,
          iconSize: 18,
          color: theme.colorScheme.onSurfaceVariant,
          icon: const Icon(TablerIcons.pin_filled),
          tooltip: L10n.of(context).unpin,
          onPressed: controller.room.canSendEvent(EventTypes.RoomPinnedEvents)
              ? () => controller.unpinEvent(event!.eventId)
              : null,
        );

        if (isMedia) {
          final caption = event.body;
          return SizedBox(
            height: ChatAppBarListTile.fixedHeight,
            child: InkWell(
              onTap: () => _displayPinnedEventsDialog(context),
              child: Row(
                children: [
                  pinButton,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: MxcImage(
                        event: event,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        isThumbnail: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        caption.isNotEmpty
                            ? caption
                            : (isVideo
                                ? L10n.of(context).video
                                : L10n.of(context).photo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ChatAppBarListTile(
          title: event?.calcLocalizedBodyFallback(
                MatrixLocals(L10n.of(context)),
                withSenderNamePrefix: true,
                hideReply: true,
              ) ??
              L10n.of(context).loadingPleaseWait,
          leading: pinButton,
          onTap: () => _displayPinnedEventsDialog(context),
        );
      },
    );
  }
}
