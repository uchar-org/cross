import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/matrix.dart';

enum _ContextAction {
  reply,
  replyInThread,
  edit,
  copy,
  forward,
  pin,
  download,
  delete,
  select,
  info,
  report,
}

class MessageContextMenu extends StatelessWidget {
  final Event event;
  final Widget child;
  final ChatController controller;
  final Timeline timeline;

  const MessageContextMenu({
    super.key,
    required this.event,
    required this.child,
    required this.controller,
    required this.timeline,
  });

  bool get _canEdit {
    if (controller.room.isArchived || !event.status.isSent) return false;
    final clients = Matrix.of(controller.context).currentBundle;
    return clients != null && clients.any((cl) => event.senderId == cl!.userID);
  }

  bool get _canRedact {
    if (controller.room.isArchived || !event.status.isSent) return false;
    final clients = Matrix.of(controller.context).currentBundle;
    return event.canRedact ||
        (clients != null && clients.any((cl) => event.senderId == cl!.userID));
  }

  bool get _canPin {
    return !controller.room.isArchived &&
        controller.room.canChangeStateEvent(EventTypes.RoomPinnedEvents) &&
        event.status.isSent &&
        controller.activeThreadId == null;
  }

  bool get _canSave {
    return {
      MessageTypes.Video,
      MessageTypes.Image,
      MessageTypes.Sticker,
      MessageTypes.Audio,
      MessageTypes.File,
    }.contains(event.messageType);
  }

  bool get _isPinned => controller.room.pinnedEventIds.contains(event.eventId);

  void _onSelected(BuildContext context, _ContextAction action) {
    switch (action) {
      case _ContextAction.reply:
        controller.replyAction(replyTo: event);
        break;
      case _ContextAction.replyInThread:
        controller.enterThread(event.eventId);
        break;
      case _ContextAction.edit:
        controller.selectSingleEvent(event);
        controller.editSelectedEventAction();
        break;
      case _ContextAction.copy:
        final displayEvent = event.getDisplayEvent(timeline);
        Clipboard.setData(
          ClipboardData(
            text: displayEvent.calcLocalizedBodyFallback(
              MatrixLocals(L10n.of(context)),
              withSenderNamePrefix: false,
              hideReply: true,
            ),
          ),
        );
        break;
      case _ContextAction.forward:
        controller.selectSingleEvent(event);
        controller.forwardEventsAction();
        break;
      case _ContextAction.pin:
        controller.selectSingleEvent(event);
        controller.pinEvent();
        controller.clearSelectedEvents();
        break;
      case _ContextAction.download:
        event.saveFile(context);
        break;
      case _ContextAction.delete:
        controller.selectSingleEvent(event);
        controller.redactEventsAction();
        break;
      case _ContextAction.select:
        controller.onSelectMessage(event);
        break;
      case _ContextAction.info:
        controller.selectSingleEvent(event);
        controller.showEventInfo();
        controller.clearSelectedEvents();
        break;
      case _ContextAction.report:
        controller.selectSingleEvent(event);
        controller.reportEventAction();
        break;
    }
  }

  List<_ContextMenuItem> _buildItems(BuildContext context) {
    final l10n = L10n.of(context);
    final room = controller.room;
    final canSendMessages = room.canSendDefaultMessages;
    final items = <_ContextMenuItem>[];

    if (canSendMessages && event.status.isSent) {
      items.add(_ContextMenuItem(
        action: _ContextAction.reply,
        icon: Icons.reply_outlined,
        label: l10n.reply,
      ));
    }

    if (canSendMessages &&
        event.status.isSent &&
        controller.activeThreadId == null) {
      items.add(_ContextMenuItem(
        action: _ContextAction.replyInThread,
        icon: Icons.message_outlined,
        label: l10n.replyInThread,
      ));
    }

    if (_canEdit && event.messageType == MessageTypes.Text) {
      items.add(_ContextMenuItem(
        action: _ContextAction.edit,
        icon: Icons.edit_outlined,
        label: l10n.edit,
      ));
    }

    if ({MessageTypes.Text, MessageTypes.Notice, MessageTypes.Emote}
        .contains(event.messageType)) {
      items.add(_ContextMenuItem(
        action: _ContextAction.copy,
        icon: Icons.copy_outlined,
        label: l10n.copyToClipboard,
      ));
    }

    if (event.status.isSent) {
      items.add(_ContextMenuItem(
        action: _ContextAction.forward,
        icon: Icons.shortcut_outlined,
        label: l10n.forward,
      ));
    }

    if (_canPin) {
      items.add(_ContextMenuItem(
        action: _ContextAction.pin,
        icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        label: _isPinned ? l10n.unpin : l10n.pinMessage,
      ));
    }

    if (_canSave) {
      items.add(_ContextMenuItem(
        action: _ContextAction.download,
        icon: Icons.download_outlined,
        label: l10n.downloadFile,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.select,
      icon: Icons.check_circle_outline,
      label: l10n.select,
    ));

    if (_canRedact) {
      items.add(_ContextMenuItem(
        action: _ContextAction.delete,
        icon: Icons.delete_outlined,
        label: l10n.redactMessage,
        isDestructive: true,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.info,
      icon: Icons.info_outlined,
      label: l10n.messageInfo,
    ));

    if (event.status.isSent && event.senderId != room.client.userID) {
      items.add(_ContextMenuItem(
        action: _ContextAction.report,
        icon: Icons.shield_outlined,
        label: l10n.reportMessage,
        isDestructive: true,
      ));
    }

    return items;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    if (event.redacted) return;

    final items = _buildItems(context);
    if (items.isEmpty) return;

    // Close any previously open context menu
    controller.closeContextMenu?.call();

    late OverlayEntry overlayEntry;
    final menuKey = GlobalKey<_ContextMenuOverlayState>();

    void removeOverlay() {
      overlayEntry.remove();
      controller.closeContextMenu = null;
    }

    Future<void> animateClose() async {
      final state = menuKey.currentState;
      if (state != null && state.mounted) {
        await state.animateOut();
      }
      removeOverlay();
    }

    overlayEntry = OverlayEntry(
      builder: (overlayContext) => _ContextMenuOverlay(
        key: menuKey,
        position: position,
        items: items,
        onSelected: (action) async {
          await animateClose();
          if (context.mounted) _onSelected(context, action);
        },
        onDismiss: () => animateClose(),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
    controller.closeContextMenu = removeOverlay;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: event.status.isSent && controller.room.canSendDefaultMessages
          ? () => controller.replyAction(replyTo: event)
          : null,
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPressStart: controller.selectedEvents.isNotEmpty
          ? null
          : (details) {
              HapticFeedback.heavyImpact();
              _showContextMenu(context, details.globalPosition);
            },
      child: child,
    );
  }
}

class _ContextMenuItem {
  final _ContextAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });
}

class _ContextMenuOverlay extends StatefulWidget {
  final Offset position;
  final List<_ContextMenuItem> items;
  final void Function(_ContextAction) onSelected;
  final VoidCallback onDismiss;

  const _ContextMenuOverlay({
    super.key,
    required this.position,
    required this.items,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
  }

  Future<void> animateOut() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    const menuWidth = 220.0;
    const itemHeight = 44.0;
    final menuHeight = widget.items.length * itemHeight;

    var left = widget.position.dx;
    var top = widget.position.dy;

    // Determine scale origin based on which edge the menu is clamped to
    var alignX = -1.0; // default: top-left origin
    var alignY = -1.0;

    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
      alignX = 1.0;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
      alignY = 1.0;
    }
    if (left < 8) left = 8;
    if (top < 8) top = 8;

    return Stack(
      children: [
        // Dismiss barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            onSecondaryTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0)
                  .animate(_scaleAnimation),
              alignment: Alignment(alignX, alignY),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: menuWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.items.map((item) {
                        final color = item.isDestructive
                            ? Colors.red
                            : theme.colorScheme.onSurface;
                        return InkWell(
                          onTap: () => widget.onSelected(item.action),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 20, color: color),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(color: color, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
