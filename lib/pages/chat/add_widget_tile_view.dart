import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter/material.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/add_widget_tile.dart';

class AddWidgetTileView extends StatelessWidget {
  final AddWidgetTileState controller;

  const AddWidgetTileView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(L10n.of(context).addWidget),
      leading: const Icon(TablerIcons.plus),
      initiallyExpanded: controller.initiallyExpanded,
      children: [
        CupertinoSegmentedControl(
          groupValue: controller.widgetType,
          padding: const EdgeInsets.all(8),
          children:
              {
                'm.etherpad': Text(L10n.of(context).widgetEtherpad),
                'm.jitsi': Text(L10n.of(context).widgetJitsi),
                'm.video': Text(L10n.of(context).widgetVideo),
                'm.custom': Text(L10n.of(context).widgetCustom),
              }.map(
                (key, value) => MapEntry(
                  key,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: value,
                  ),
                ),
              ),
          onValueChanged: controller.setWidgetType,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: controller.nameController,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(TablerIcons.tag),
              label: Text(L10n.of(context).widgetName),
              errorText: controller.nameError,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: controller.urlController,
            decoration: InputDecoration(
              prefixIcon: const Icon(TablerIcons.link),
              label: Text(L10n.of(context).link),
              errorText: controller.urlError,
            ),
          ),
        ),
        OverflowBar(
          children: [
            TextButton(
              onPressed: controller.addWidget,
              child: Text(L10n.of(context).addWidget),
            ),
          ],
        ),
      ],
    );
  }
}
