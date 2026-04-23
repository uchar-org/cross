import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_details/chat_details.dart';
import 'package:fluffychat/pages/chat_details/participant_list_item.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/chat_settings_popup_menu.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../utils/url_launcher.dart';
import '../../widgets/mxc_image_viewer.dart';
import '../../widgets/qr_code_viewer.dart';

class ChatDetailsView extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final room = Matrix.of(context).client.getRoomById(controller.roomId!);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
        ),
      );
    }

    final directChatMatrixID = room.directChatMatrixID;
    final roomAvatar = room.avatar;

    return StreamBuilder(
      stream: room.client.onRoomState.stream.where(
        (update) => update.roomId == room.id,
      ),
      builder: (context, snapshot) {
        final actualMembersCount =
            (room.summary.mInvitedMemberCount ?? 0) +
            (room.summary.mJoinedMemberCount ?? 0);
        final iconColor = theme.textTheme.bodyLarge!.color;
        final displayname = room.getLocalizedDisplayname(
          MatrixLocals(L10n.of(context)),
        );
        final displayedMembers = controller.displayedMembers;

        return Scaffold(
          appBar: AppBar(
            leading:
                controller.widget.embeddedCloseButton ??
                const Center(child: BackButton()),
            elevation: theme.appBarTheme.elevation,
            actions: <Widget>[
              if (room.canonicalAlias.isNotEmpty)
                IconButton(
                  tooltip: L10n.of(context).share,
                  icon: const Icon(TablerIcons.qrcode),
                  onPressed: () =>
                      showQrCodeViewer(context, room.canonicalAlias),
                )
              else if (directChatMatrixID != null)
                IconButton(
                  tooltip: L10n.of(context).share,
                  icon: const Icon(TablerIcons.qrcode),
                  onPressed: () =>
                      showQrCodeViewer(context, directChatMatrixID),
                ),
              if (controller.widget.embeddedCloseButton == null)
                ChatSettingsPopupMenu(room, false),
            ],
            title: Text(L10n.of(context).chatDetails),
            backgroundColor: theme.appBarTheme.backgroundColor,
          ),
          body: MaxWidthBody(
            withScrolling: false,
            child: ListView.builder(
              controller: controller.scrollController,
              itemCount:
                  displayedMembers.length +
                  1 +
                  (controller.loadingMembers ? 1 : 0),
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: .stretch,
                    children: <Widget>[
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Stack(
                              children: [
                                Hero(
                                  tag:
                                      controller.widget.embeddedCloseButton !=
                                          null
                                      ? 'embedded_content_banner'
                                      : 'content_banner',
                                  child: Avatar(
                                    mxContent: room.avatar,
                                    name: displayname,
                                    size: Avatar.defaultSize * 2.5,
                                    onTap: roomAvatar != null
                                        ? () => showDialog(
                                            context: context,
                                            builder: (_) =>
                                                MxcImageViewer(roomAvatar),
                                          )
                                        : null,
                                  ),
                                ),
                                if (!room.isDirectChat &&
                                    room.canChangeStateEvent(
                                      EventTypes.RoomAvatar,
                                    ))
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: FloatingActionButton.small(
                                      onPressed: controller.setAvatarAction,
                                      heroTag: null,
                                      child: const Icon(
                                        TablerIcons.camera,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: .center,
                              crossAxisAlignment: .start,
                              children: [
                                TextButton.icon(
                                  onPressed: () => room.isDirectChat
                                      ? null
                                      : room.canChangeStateEvent(
                                          EventTypes.RoomName,
                                        )
                                      ? controller.setDisplaynameAction()
                                      : FluffyShare.share(
                                          displayname,
                                          context,
                                          copyOnly: true,
                                        ),
                                  icon: Icon(
                                    room.isDirectChat
                                        ? TablerIcons.message
                                        : room.canChangeStateEvent(
                                            EventTypes.RoomName,
                                          )
                                        ? TablerIcons.pencil
                                        : TablerIcons.copy,
                                    size: 16,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.onSurface,
                                    iconColor: theme.colorScheme.onSurface,
                                  ),
                                  label: Text(
                                    room.isDirectChat
                                        ? L10n.of(context).directChat
                                        : displayname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => room.isDirectChat
                                      ? null
                                      : context.push(
                                          '/rooms/${controller.roomId}/details/members',
                                        ),
                                  icon: const Icon(
                                    TablerIcons.users,
                                    size: 14,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.secondary,
                                    iconColor: theme.colorScheme.secondary,
                                  ),
                                  label: Text(
                                    L10n.of(
                                      context,
                                    ).countParticipants(actualMembersCount),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (room.canChangeStateEvent(EventTypes.RoomTopic) ||
                          room.topic.isNotEmpty) ...[
                        Divider(color: theme.dividerColor),
                        ListTile(
                          title: Text(
                            L10n.of(context).chatDescription,
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing:
                              room.canChangeStateEvent(EventTypes.RoomTopic)
                              ? IconButton(
                                  onPressed: controller.setTopicAction,
                                  tooltip: L10n.of(
                                    context,
                                  ).setChatDescription,
                                  icon: const Icon(TablerIcons.pencil),
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                          child: SelectableLinkify(
                            text: room.topic.isEmpty
                                ? L10n.of(context).noChatDescriptionYet
                                : room.topic,
                            textScaleFactor: MediaQuery.textScalerOf(
                              context,
                            ).scale(1),
                            options: const LinkifyOptions(humanize: false),
                            linkStyle: const TextStyle(
                              color: Colors.blueAccent,
                              decorationColor: Colors.blueAccent,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: room.topic.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: theme.textTheme.bodyMedium!.color,
                              decorationColor:
                                  theme.textTheme.bodyMedium!.color,
                            ),
                            onOpen: (url) =>
                                UrlLauncher(context, url.url).launchUrl(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!room.isDirectChat) ...[
                        Divider(color: theme.dividerColor),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.surfaceContainer,
                            foregroundColor: iconColor,
                            child: const Icon(
                              TablerIcons.shield_half_filled,
                            ),
                          ),
                          title: Text(L10n.of(context).accessAndVisibility),
                          subtitle: Text(
                            L10n.of(context).accessAndVisibilityDescription,
                          ),
                          onTap: () => context.push(
                            '/rooms/${room.id}/details/access',
                          ),
                          trailing: const Icon(TablerIcons.chevron_right),
                        ),
                        ListTile(
                          title: Text(L10n.of(context).chatPermissions),
                          subtitle: Text(
                            L10n.of(context).whoCanPerformWhichAction,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.surfaceContainer,
                            foregroundColor: iconColor,
                            child: const Icon(
                              TablerIcons.adjustments_horizontal,
                            ),
                          ),
                          trailing: const Icon(TablerIcons.chevron_right),
                          onTap: () => context.push(
                            '/rooms/${room.id}/details/permissions',
                          ),
                        ),
                      ],
                      Divider(color: theme.dividerColor),
                      ListTile(
                        leading: Icon(
                          TablerIcons.users,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                        title: Text(
                          L10n.of(
                            context,
                          ).countParticipants(actualMembersCount),
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            controller.showMemberSearch
                                ? TablerIcons.x
                                : TablerIcons.search,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                          onPressed: controller.toggleMemberSearch,
                        ),
                      ),
                      if (controller.showMemberSearch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextField(
                            autofocus: true,
                            onChanged: controller.setMemberSearchQuery,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor:
                                  theme.colorScheme.secondaryContainer,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              hintStyle: TextStyle(
                                color:
                                    theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: const Icon(
                                TablerIcons.search,
                                size: 18,
                              ),
                              hintText: L10n.of(context).search,
                              isDense: true,
                            ),
                          ),
                        ),
                      if (!room.isDirectChat && room.canInvite)
                        ListTile(
                          title: Text(L10n.of(context).inviteContact),
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                            radius: Avatar.defaultSize / 2,
                            child: const Icon(TablerIcons.plus),
                          ),
                          trailing: const Icon(TablerIcons.chevron_right),
                          onTap: () =>
                              context.go('/rooms/${room.id}/invite'),
                        ),
                    ],
                  );
                }

                if (i <= displayedMembers.length) {
                  return ParticipantListItem(displayedMembers[i - 1]);
                }

                // Loading indicator at the bottom
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
