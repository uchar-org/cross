import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tabler_icons/tabler_icons.dart';

import 'package:matrix/matrix.dart';

IconData _getIconFromName(String displayname) {
  final name = displayname.toLowerCase();
  if ({'android'}.any((s) => name.contains(s))) {
    return TablerIcons.device_mobile;
  }
  if ({'ios', 'ipad', 'iphone', 'ipod'}.any((s) => name.contains(s))) {
    return TablerIcons.device_mobile;
  }
  if ({
    'web',
    'http://',
    'https://',
    'firefox',
    'chrome',
    '/_matrix',
    'safari',
    'opera',
  }.any((s) => name.contains(s))) {
    return TablerIcons.world;
  }
  if ({
    'desktop',
    'windows',
    'macos',
    'linux',
    'ubuntu',
  }.any((s) => name.contains(s))) {
    return TablerIcons.device_desktop;
  }
  return TablerIcons.help;
}

extension DeviceExtension on Device {
  String get displayname =>
      (displayName?.isNotEmpty ?? false) ? displayName! : 'Unknown device';

  IconData get icon => _getIconFromName(displayname);
}

extension DeviceKeysExtension on DeviceKeys {
  String get displayname => (deviceDisplayName?.isNotEmpty ?? false)
      ? deviceDisplayName!
      : 'Unknown device';

  IconData get icon => _getIconFromName(displayname);
}
