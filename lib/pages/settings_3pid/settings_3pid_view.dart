import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/settings_3pid/settings_3pid.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:matrix/matrix.dart';

class Settings3PidView extends StatelessWidget {
  final Settings3PidController controller;

  const Settings3PidView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    controller.request ??= Matrix.of(context).client.getAccount3PIDs();
    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(L10n.of(context).passwordRecovery),
        actions: [
          IconButton(
            icon: const Icon(TablerIcons.plus),
            onPressed: controller.add3PidAction,
            tooltip: L10n.of(context).addEmail,
          ),
        ],
      ),
      body: MaxWidthBody(
        withScrolling: false,
        child: FutureBuilder<List<ThirdPartyIdentifier>?>(
          future: controller.request,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ThirdPartyIdentifier>?> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  );
                }
                final identifier = snapshot.data!;
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.scaffoldBackgroundColor,
                        foregroundColor: identifier.isEmpty
                            ? Colors.orange
                            : Colors.grey,
                        child: Icon(
                          identifier.isEmpty
                              ? TablerIcons.alert_triangle
                              : TablerIcons.info_circle,
                        ),
                      ),
                      title: Text(
                        identifier.isEmpty
                            ? L10n.of(context).noPasswordRecoveryDescription
                            : L10n.of(
                                context,
                              ).withTheseAddressesRecoveryDescription,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: identifier.length,
                        itemBuilder: (BuildContext context, int i) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.scaffoldBackgroundColor,
                            foregroundColor: Colors.grey,
                            child: Icon(identifier[i].iconData),
                          ),
                          title: Text(identifier[i].address),
                          trailing: IconButton(
                            tooltip: L10n.of(context).delete,
                            icon: const Icon(TablerIcons.trash_filled),
                            color: Colors.red,
                            onPressed: () =>
                                controller.delete3Pid(identifier[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

extension on ThirdPartyIdentifier {
  IconData get iconData {
    switch (medium) {
      case ThirdPartyIdentifierMedium.email:
        return TablerIcons.mail;
      case ThirdPartyIdentifierMedium.msisdn:
        return TablerIcons.device_mobile;
    }
  }
}
