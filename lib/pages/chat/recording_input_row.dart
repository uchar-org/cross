import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat_input_row.dart';
import 'package:fluffychat/pages/chat/recording_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class RecordingInputRow extends StatelessWidget {
  final RecordingViewModelState state;
  final Future<void> Function(String, int, List<int>, String) onSend;
  const RecordingInputRow({
    required this.state,
    required this.onSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const maxDecibalWidth = 36.0;
    final time =
        '${state.duration.inMinutes.toString().padLeft(2, '0')}:${(state.duration.inSeconds % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      height: ChatInputRow.height,
      child: Row(
        crossAxisAlignment: .center,
        mainAxisAlignment: .spaceBetween,
        children: [
          const SizedBox(width: 4),
          Container(
            alignment: .center,
            width: 48,
            child: IconButton(
              tooltip: L10n.of(context).cancel,
              icon: const Icon(TablerIcons.trash),
              color: theme.colorScheme.error,
              onPressed: state.cancel,
            ),
          ),
          if (state.isPaused)
            Container(
              alignment: .center,
              width: 48,
              child: IconButton(
                tooltip: L10n.of(context).resume,
                icon: const Icon(TablerIcons.player_play),
                onPressed: state.resume,
              ),
            )
          else
            Container(
              alignment: .center,
              width: 48,
              child: IconButton(
                tooltip: L10n.of(context).pause,
                icon: const Icon(TablerIcons.player_pause),
                onPressed: state.pause,
              ),
            ),
          Text(time),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const width = 4;
                return Row(
                  mainAxisSize: .min,
                  mainAxisAlignment: .end,
                  children: state.amplitudeTimeline.reversed
                      .take((constraints.maxWidth / (width + 2)).floor())
                      .toList()
                      .reversed
                      .map(
                        (amplitude) => Container(
                          margin: const EdgeInsets.only(left: 2),
                          width: width.toDouble(),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          height: maxDecibalWidth * (amplitude / 100),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              disabledBackgroundColor: theme.bubbleColor.withAlpha(128),
              backgroundColor: theme.bubbleColor,
              foregroundColor: theme.onBubbleColor,
            ),
            tooltip: L10n.of(context).sendAudio,
            icon: state.isSending
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Icon(TablerIcons.send),
            onPressed: state.isSending ? null : () => state.stopAndSend(onSend),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
