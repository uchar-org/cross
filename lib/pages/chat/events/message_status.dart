import 'package:fluffychat/pages/chat/events/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tabler_icons/tabler_icons.dart';

class MessageStatusWidget extends StatelessWidget {
  final MessageStatus? status;
  final Color iconColor;
  const MessageStatusWidget({super.key, required this.status, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        switch (status) {
          case null:
            {
              return SizedBox.shrink();
            }
          case MessageStatus.seen:
            {
              return Icon(TablerIcons.checks, size: 14, color: iconColor);
            }
          case MessageStatus.pending:
            {
              return Icon(TablerIcons.clock, size: 14, color: iconColor);
            }
          case MessageStatus.sent:
            {
              return Icon(TablerIcons.check, size: 14, color: iconColor);
            }
          case MessageStatus.error:
            {
              return Icon(
                TablerIcons.alert_circle_filled,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              );
            }
        }
      },
    );
  }
}
