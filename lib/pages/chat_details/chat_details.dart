import 'dart:async';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_details/chat_details_view.dart';
import 'package:fluffychat/utils/file_selector.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:fluffychat/pages/settings/settings.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

enum AliasActions { copy, delete, setCanonical }

class ChatDetails extends StatefulWidget {
  final String roomId;
  final Widget? embeddedCloseButton;

  const ChatDetails({
    super.key,
    required this.roomId,
    this.embeddedCloseButton,
  });

  @override
  ChatDetailsController createState() => ChatDetailsController();
}

class ChatDetailsController extends State<ChatDetails> {
  bool displaySettings = false;

  void toggleDisplaySettings() =>
      setState(() => displaySettings = !displaySettings);

  String? get roomId => widget.roomId;

  // Member search state
  bool showMemberSearch = false;
  String memberSearchQuery = '';

  void toggleMemberSearch() {
    setState(() {
      showMemberSearch = !showMemberSearch;
      if (!showMemberSearch) {
        memberSearchQuery = '';
        _displayedCount = _pageSize;
      }
    });
    _applyMemberFilter();
  }

  void setMemberSearchQuery(String query) {
    setState(() {
      memberSearchQuery = query;
      _displayedCount = _pageSize;
    });
    _applyMemberFilter();
  }

  // Member list state
  static const int _pageSize = 20;
  List<User>? _allMembers;
  List<User>? _filteredMembers;
  int _displayedCount = _pageSize;
  bool loadingMembers = false;

  List<User> get displayedMembers {
    final source = _filteredMembers ?? [];
    return source.take(_displayedCount).toList();
  }

  bool get hasMoreMembers {
    final source = _filteredMembers ?? [];
    return _displayedCount < source.length;
  }

  // Scroll
  late final ScrollController scrollController;
  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allMembers == null && !loadingMembers) {
      _loadMembers();
      _memberSub ??= Matrix.of(context).client.onSync.stream
          .where(
            (update) =>
                update.rooms?.join?[widget.roomId]?.timeline?.events?.any(
                  (e) => e.type == EventTypes.RoomMember,
                ) ??
                false,
          )
          .listen((_) => _loadMembers());
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    _memberSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (loadingMembers) return;
    setState(() => loadingMembers = true);
    try {
      final room = Matrix.of(context).client.getRoomById(widget.roomId);
      if (room == null) return;
      final participants = await room.requestParticipants(
        [Membership.join, Membership.invite, Membership.knock],
      );
      participants.sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));
      if (!mounted) return;
      setState(() {
        _allMembers = participants;
        loadingMembers = false;
      });
      _applyMemberFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingMembers = false);
    }
  }

  void _applyMemberFilter() {
    if (_allMembers == null) return;
    if (memberSearchQuery.isEmpty) {
      setState(() => _filteredMembers = _allMembers);
    } else {
      final query = memberSearchQuery.toLowerCase();
      setState(() {
        _filteredMembers = _allMembers!
            .where(
              (m) =>
                  (m.displayName ?? '').toLowerCase().contains(query) ||
                  m.id.toLowerCase().contains(query),
            )
            .toList();
      });
    }
  }

  void _onScroll() {
    if (!hasMoreMembers) return;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 300) {
      setState(() => _displayedCount += _pageSize);
    }
  }

  Future<void> leaveRoom() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.areYouSure),
        content: Text(l10n.commandHint_leave),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final room = Matrix.of(context).client.getRoomById(widget.roomId);
    if (room == null) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: room.leave,
    );
    if (!mounted) return;
    if (success.error == null) context.go('/rooms');
  }

  Future<void> muteUnmuteAction() async {
    final room = Matrix.of(context).client.getRoomById(widget.roomId);
    if (room == null) return;
    final isMuted = room.pushRuleState != PushRuleState.notify;
    await showFutureLoadingDialog(
      context: context,
      future: () => room.setPushRuleState(
        isMuted ? PushRuleState.notify : PushRuleState.mentionsOnly,
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> setDisplaynameAction() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!)!;
    final input = await showTextInputDialog(
      context: context,
      title: l10n.changeTheNameOfTheGroup,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      initialText: room.getLocalizedDisplayname(MatrixLocals(l10n)),
    );
    if (input == null) return;
    if (!mounted) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => room.setName(input),
    );
    if (!mounted) return;
    if (success.error == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.displaynameHasBeenChanged)),
      );
    }
  }

  Future<void> setTopicAction() async {
    final l10n = L10n.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!)!;
    final input = await showTextInputDialog(
      context: context,
      title: l10n.setChatDescription,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      hintText: l10n.noChatDescriptionYet,
      initialText: room.topic,
      minLines: 4,
      maxLines: 8,
    );
    if (input == null) return;
    if (!mounted) return;
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => room.setDescription(input),
    );
    if (!mounted) return;
    if (success.error == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.chatDescriptionHasBeenChanged)),
      );
    }
  }

  Future<void> setAvatarAction() async {
    final l10n = L10n.of(context);
    final room = Matrix.of(context).client.getRoomById(roomId!);
    final actions = [
      if (PlatformInfos.isMobile)
        AdaptiveModalAction(
          value: AvatarAction.camera,
          label: l10n.openCamera,
          isDefaultAction: true,
          icon: const Icon(TablerIcons.camera),
        ),
      AdaptiveModalAction(
        value: AvatarAction.file,
        label: l10n.openGallery,
        icon: const Icon(TablerIcons.photo),
      ),
      if (room?.avatar != null)
        AdaptiveModalAction(
          value: AvatarAction.remove,
          label: l10n.delete,
          isDestructive: true,
          icon: const Icon(TablerIcons.trash),
        ),
    ];
    final action = actions.length == 1
        ? actions.single.value
        : await showModalActionPopup<AvatarAction>(
            context: context,
            title: l10n.editRoomAvatar,
            cancelLabel: l10n.cancel,
            actions: actions,
          );
    if (action == null) return;
    if (!mounted) return;
    if (action == AvatarAction.remove) {
      await showFutureLoadingDialog(
        context: context,
        future: () => room!.setAvatar(null),
      );
      return;
    }
    MatrixFile file;
    if (PlatformInfos.isMobile) {
      final result = await ImagePicker().pickImage(
        source: action == AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 50,
      );
      if (result == null) return;
      file = MatrixFile(bytes: await result.readAsBytes(), name: result.path);
    } else {
      if (!mounted) return;
      final picked = await selectFiles(
        context,
        allowMultiple: false,
        type: FileType.image,
      );
      final pickedFile = picked.firstOrNull;
      if (pickedFile == null) return;
      file = MatrixFile(
        bytes: await pickedFile.readAsBytes(),
        name: pickedFile.name,
      );
    }
    if (!mounted) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => room!.setAvatar(file),
    );
  }

  static const fixedWidth = 360.0;

  @override
  Widget build(BuildContext context) => ChatDetailsView(this);
}
