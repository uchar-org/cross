import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter/services.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/user_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
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
        icon: TablerIcons.arrow_back_up,
        label: l10n.reply,
      ));
    }

    if (canSendMessages &&
        event.status.isSent &&
        controller.activeThreadId == null) {
      items.add(_ContextMenuItem(
        action: _ContextAction.replyInThread,
        icon: TablerIcons.message,
        label: l10n.replyInThread,
      ));
    }

    if (_canEdit && event.messageType == MessageTypes.Text) {
      items.add(_ContextMenuItem(
        action: _ContextAction.edit,
        icon: TablerIcons.pencil,
        label: l10n.edit,
      ));
    }

    if ({MessageTypes.Text, MessageTypes.Notice, MessageTypes.Emote}
        .contains(event.messageType)) {
      items.add(_ContextMenuItem(
        action: _ContextAction.copy,
        icon: TablerIcons.copy,
        label: l10n.copyToClipboard,
      ));
    }

    if (event.status.isSent) {
      items.add(_ContextMenuItem(
        action: _ContextAction.forward,
        icon: TablerIcons.corner_down_right,
        label: l10n.forward,
      ));
    }

    if (_canPin) {
      items.add(_ContextMenuItem(
        action: _ContextAction.pin,
        icon: _isPinned ? TablerIcons.pin_filled : TablerIcons.pin,
        label: _isPinned ? l10n.unpin : l10n.pinMessage,
      ));
    }

    if (_canSave) {
      items.add(_ContextMenuItem(
        action: _ContextAction.download,
        icon: TablerIcons.cloud_download,
        label: l10n.downloadFile,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.select,
      icon: TablerIcons.circle_check,
      label: l10n.select,
    ));

    if (_canRedact) {
      items.add(_ContextMenuItem(
        action: _ContextAction.delete,
        icon: TablerIcons.trash,
        label: l10n.redactMessage,
        isDestructive: true,
      ));
    }

    items.add(_ContextMenuItem(
      action: _ContextAction.info,
      icon: TablerIcons.info_circle,
      label: l10n.messageInfo,
    ));

    if (event.status.isSent && event.senderId != room.client.userID) {
      items.add(_ContextMenuItem(
        action: _ContextAction.report,
        icon: TablerIcons.shield,
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

    final seenUsers = event.room.getSeenByUsers(
      timeline,
      eventId: event.eventId,
    );
    final otherUserReceipts = event.room.receiptState.global.otherUsers;
    final seenByReceipts = seenUsers.map((user) {
      final time =
          otherUserReceipts[user.id]?.timestamp ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return Receipt(user, time);
    }).toList();

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

    final editedAt = event.hasAggregatedEvents(timeline, RelationshipTypes.edit)
        ? event.getDisplayEvent(timeline).originServerTs
        : null;

    overlayEntry = OverlayEntry(
      builder: (overlayContext) => _ContextMenuOverlay(
        key: menuKey,
        position: position,
        items: items,
        seenByReceipts: seenByReceipts,
        editedAt: editedAt,
        onSelected: (action) async {
          await animateClose();
          if (context.mounted) _onSelected(context, action);
        },
        onDismiss: animateClose,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
    controller.closeContextMenu = removeOverlay;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = PlatformInfos.isDesktop || PlatformInfos.isWeb;

    return GestureDetector(
      onDoubleTap: event.status.isSent && controller.room.canSendDefaultMessages
          ? () => controller.replyAction(replyTo: event)
          : null,
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPressStart: isDesktopOrWeb
          ? null
          : controller.selectedEvents.isNotEmpty
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
  final List<Receipt> seenByReceipts;
  final DateTime? editedAt;
  final void Function(_ContextAction) onSelected;
  final VoidCallback onDismiss;

  const _ContextMenuOverlay({
    super.key,
    required this.position,
    required this.items,
    required this.seenByReceipts,
    this.editedAt,
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
    const seenByRowHeight = 40.0;
    final menuHeight = widget.items.length * itemHeight +
        (widget.seenByReceipts.isNotEmpty ? seenByRowHeight + 1 : 0);

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
                      children: [
                        ...widget.items.map((item) {
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
                                    style:
                                        TextStyle(color: color, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (widget.seenByReceipts.isNotEmpty ||
                            widget.editedAt != null) ...[
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          ),
                          if (widget.seenByReceipts.isNotEmpty)
                            _SeenByMenuRow(receipts: widget.seenByReceipts),
                          if (widget.seenByReceipts.isNotEmpty &&
                              widget.editedAt != null)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outline.withValues(alpha: 0.08),
                            ),
                          if (widget.editedAt != null)
                            _EditedAtRow(editedAt: widget.editedAt!),
                        ],
                      ],
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

class _SeenByMenuRow extends StatefulWidget {
  final List<Receipt> receipts;

  const _SeenByMenuRow({required this.receipts});

  @override
  State<_SeenByMenuRow> createState() => _SeenByMenuRowState();
}

class _SeenByMenuRowState extends State<_SeenByMenuRow> {
  OverlayEntry? _submenu;
  Timer? _closeTimer;

  static const _submenuWidth = 220.0;
  static const _gap = 6.0;

  void _showSubmenu() {
    _closeTimer?.cancel();
    _closeTimer = null;
    if (_submenu != null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final rowTopLeft = renderBox.localToGlobal(Offset.zero);
    final rowSize = renderBox.size;
    final screen = MediaQuery.sizeOf(context);

    final openRight =
        rowTopLeft.dx + rowSize.width + _gap + _submenuWidth <= screen.width;

    final left = openRight
        ? rowTopLeft.dx + rowSize.width + _gap
        : rowTopLeft.dx - _submenuWidth - _gap;

    const itemHeight = 52.0;
    final submenuHeight = widget.receipts.length * itemHeight + 16.0;
    final top = (rowTopLeft.dy).clamp(8.0, screen.height - submenuHeight - 8);

    _submenu = OverlayEntry(
      builder: (ctx) => _SeenBySubmenuOverlay(
        left: left,
        top: top,
        openRight: openRight,
        receipts: widget.receipts,
        onMouseEnter: _cancelClose,
        onMouseExit: _scheduleClose,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_submenu!);
    if (mounted) setState(() {});
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 200), () {
      _submenu?.remove();
      _submenu = null;
      if (mounted) setState(() {});
    });
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _submenu?.remove();
    _submenu = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipts = widget.receipts;
    final isOpen = _submenu != null;

    const maxAvatars = 3;
    const avatarSize = 18.0;
    const ringWidth = 1.5;
    const totalAvatarSize = avatarSize + ringWidth * 2;
    const step = 12.0; // left-edge distance between consecutive avatars

    final displayReceipts = receipts.take(maxAvatars).toList();
    final stackWidth =
        totalAvatarSize + (displayReceipts.length - 1) * step;

    return MouseRegion(
      onEnter: (_) => _showSubmenu(),
      onExit: (_) => _scheduleClose(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: isOpen
            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                TablerIcons.eye,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                '${receipts.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Stacked overlapping avatars aligned to the right
              SizedBox(
                width: stackWidth,
                height: totalAvatarSize,
                child: Stack(
                  children: [
                    for (int i = displayReceipts.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * step,
                        child: Container(
                          padding: const EdgeInsets.all(ringWidth),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? theme.colorScheme.surfaceContainerHigh
                                : theme.colorScheme.surfaceContainer,
                          ),
                          child: Avatar(
                            mxContent: displayReceipts[i].user.avatarUrl,
                            name: displayReceipts[i].user.calcDisplayname(),
                            size: avatarSize,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeenBySubmenuOverlay extends StatelessWidget {
  final double left;
  final double top;
  final bool openRight;
  final List<Receipt> receipts;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;

  const _SeenBySubmenuOverlay({
    required this.left,
    required this.top,
    required this.openRight,
    required this.receipts,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            builder: (ctx, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(openRight ? (1 - t) * 8 : (t - 1) * 8, 0),
                child: child,
              ),
            ),
            child: MouseRegion(
              onEnter: (_) => onMouseEnter(),
              onExit: (_) => onMouseExit(),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 220,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: receipts
                          .map((r) => _SeenByUserRow(receipt: r))
                          .toList(),
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

class _SeenByUserRow extends StatelessWidget {
  final Receipt receipt;

  const _SeenByUserRow({required this.receipt});

  void _openProfile(BuildContext context) => UserDialog.show(
        context: context,
        profile: Profile(
          userId: receipt.user.id,
          displayName: receipt.user.displayName,
          avatarUrl: receipt.user.avatarUrl,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openProfile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Avatar(
              mxContent: receipt.user.avatarUrl,
              name: receipt.user.calcDisplayname(),
              size: 32,
              onTap: () => _openProfile(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    receipt.user.calcDisplayname(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    receipt.time.localizedTime(context),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditedAtRow extends StatelessWidget {
  final DateTime editedAt;

  const _EditedAtRow({required this.editedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(TablerIcons.pencil, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            editedAt.localizedTime(context),
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}
