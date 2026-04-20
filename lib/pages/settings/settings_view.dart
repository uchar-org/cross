import 'package:fluffychat/config/locale_provide.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:language_picker/languages.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../widgets/mxc_image_viewer.dart';
import 'settings.dart';

class SettingsView extends StatelessWidget {
  final SettingsController controller;

  const SettingsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();

    final theme = Theme.of(context);
    final activeRoute = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settings),
        leading: Center(
          child: BackButton(onPressed: () => context.go('/rooms')),
        ),
      ),
      body: ListTileTheme(
        iconColor: theme.colorScheme.onSurface,
        child: ListView(
          key: const Key('SettingsListViewContent'),
          children: <Widget>[
            FutureBuilder<Profile>(
              future: controller.profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final avatar = profile?.avatarUrl;
                final mxid =
                    Matrix.of(context).client.userID ?? L10n.of(context).user;
                final displayname =
                    profile?.displayName ?? mxid.localpart ?? mxid;
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Stack(
                        children: [
                          Avatar(
                            mxContent: avatar,
                            name: displayname,
                            size: Avatar.defaultSize * 2.5,
                            onTap: avatar != null
                                ? () => showDialog(
                                    context: context,
                                    builder: (_) => MxcImageViewer(avatar),
                                  )
                                : null,
                          ),
                          if (profile != null)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: FloatingActionButton.small(
                                elevation: 2,
                                onPressed: controller.setAvatarAction,
                                heroTag: null,
                                child: const Icon(TablerIcons.camera),
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
                            onPressed: controller.setDisplaynameAction,
                            icon: const Icon(TablerIcons.pencil, size: 16),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface,
                              iconColor: theme.colorScheme.onSurface,
                            ),
                            label: Text(
                              displayname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => FluffyShare.share(mxid, context),
                            icon: const Icon(TablerIcons.copy, size: 14),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.secondary,
                              iconColor: theme.colorScheme.secondary,
                            ),
                            label: Text(
                              mxid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              //    style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            FutureBuilder(
              future: Matrix.of(context).client.getAuthMetadata(),
              builder: (context, snapshot) {
                final accountManageUrl = snapshot.data?.issuer;
                if (accountManageUrl == null) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(TablerIcons.user_circle),
                  title: Text(L10n.of(context).manageAccount),
                  trailing: const Icon(TablerIcons.external_link),
                  onTap: () => launchUrl(
                    accountManageUrl,
                    mode: LaunchMode.inAppBrowserView,
                  ),
                );
              },
            ),
            Divider(color: theme.dividerColor),
            SwitchListTile.adaptive(
              controlAffinity: ListTileControlAffinity.trailing,
              value: controller.cryptoIdentityConnected == true,
              secondary: const Icon(TablerIcons.cloud_upload),
              title: Text(L10n.of(context).chatBackup),
              onChanged: controller.firstRunBootstrapAction,
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(TablerIcons.brush),
              title: Text(L10n.of(context).changeTheme),
              tileColor: activeRoute.startsWith('/rooms/settings/style')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/style'),
            ),
            ListTile(
              leading: const Icon(TablerIcons.bell),
              title: Text(L10n.of(context).notifications),
              tileColor: activeRoute.startsWith('/rooms/settings/notifications')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/notifications'),
            ),
            ListTile(
              leading: const Icon(TablerIcons.device_mobile),
              title: Text(L10n.of(context).devices),
              onTap: () => context.go('/rooms/settings/devices'),
              tileColor: activeRoute.startsWith('/rooms/settings/devices')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(TablerIcons.messages),
              title: Text(L10n.of(context).chat),
              onTap: () => context.go('/rooms/settings/chat'),
              tileColor: activeRoute.startsWith('/rooms/settings/chat')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(TablerIcons.shield),
              title: Text(L10n.of(context).security),
              onTap: () => context.go('/rooms/settings/security'),
              tileColor: activeRoute.startsWith('/rooms/settings/security')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.0),
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonFormField<Language>(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(TablerIcons.world),
                    filled: false,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                  ),
                  isExpanded: true,
                  onChanged: (value) {
                    if (value != null) {
                      localeProvider.setLanguage(value);
                    }
                  },
                  items: localeProvider.languages
                      .map(
                        (language) => DropdownMenuItem<Language>(
                      value: language,
                      child: Text(
                        '${language.name} (${language.isoCode})',
                        style: TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ),
                  )
                      .toList(),
                  initialValue: localeProvider.language,
                ),
              ),
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(TablerIcons.server),
              title: Text(
                L10n.of(context).aboutHomeserver(
                  Matrix.of(context).client.userID?.domain ?? 'homeserver',
                ),
              ),
              onTap: () => context.go('/rooms/settings/homeserver'),
              tileColor: activeRoute.startsWith('/rooms/settings/homeserver')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(TablerIcons.shield),
              title: Text(L10n.of(context).privacy),
              onTap: () => launchUrlString(AppSettings.privacyPolicy.value),
            ),
            ListTile(
              leading: const Icon(TablerIcons.info_circle),
              title: Text(L10n.of(context).about),
              onTap: () => PlatformInfos.showDialog(context),
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(TablerIcons.logout),
              title: Text(L10n.of(context).logout),
              onTap: controller.logoutAction,
            ),
          ],
        ),
      ),
    );
  }
}
