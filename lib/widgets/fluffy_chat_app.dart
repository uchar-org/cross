import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluffychat/config/routes.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/config/locale_provide.dart';
import 'package:fluffychat/widgets/app_lock.dart';
import 'package:fluffychat/widgets/theme_builder.dart';
import '../utils/custom_scroll_behaviour.dart';
import 'check_root.dart';
import 'matrix.dart';

class FluffyChatApp extends StatefulWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final String? pincode;
  final SharedPreferences store;

  FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  /// getInitialLink may rereturn the value multiple times if this view is
  /// opened multiple times for example if the user logs out after they logged
  /// in with qr code or magic link.
  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
  );

  @override
  State<FluffyChatApp> createState() => _FluffyChatAppState();
}

class _FluffyChatAppState extends State<FluffyChatApp> {
  String text = '';
  bool isRoot = false;

  void processCheckJailbreakRoot() async {
    final isNotTrust = await JailbreakRootDetection.instance.isNotTrust;
    final isRealDevice = await JailbreakRootDetection.instance.isRealDevice;
    if (Platform.isAndroid) {
      try {
        final isNotTrust = await JailbreakRootDetection.instance.isNotTrust;
        final isJailBroken = await JailbreakRootDetection.instance.isJailBroken;
        final isRealDevice = await JailbreakRootDetection.instance.isRealDevice;
        final isOnExternalStorage =
            await JailbreakRootDetection.instance.isOnExternalStorage;
        final checkForIssues =
            await JailbreakRootDetection.instance.checkForIssues;
        final isDevMode = await JailbreakRootDetection.instance.isDevMode;
        if (isJailBroken) {
          isRoot = true;
          text="Your phone is rooted.";
        }
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
    if (Platform.isIOS) {
      final isNotTrust = await JailbreakRootDetection.instance.isNotTrust;
      final isJailBroken = await JailbreakRootDetection.instance.isJailBroken;
      final isRealDevice = await JailbreakRootDetection.instance.isRealDevice;
      final checkForIssues =
          await JailbreakRootDetection.instance.checkForIssues;

      final bundleId =
          'uz.uzinfocom.uchar'; // Ex: final bundleId = 'com.w3conext.jailbreakRootDetectionExample'
      final isTampered = await JailbreakRootDetection.instance.isTampered(
        bundleId,
      );
      if (isJailBroken) {
        isRoot = true;
        text="Your phone is rooted.";
      }
    }

    final checkForIssues = await JailbreakRootDetection.instance.checkForIssues;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    processCheckJailbreakRoot();
  }

  @override
  Widget build(BuildContext context) {
    return isRoot
        ? CheckRoot(text: '',)
        : ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: ThemeBuilder(
        builder: (context, themeMode, primaryColor) {
          return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  title: AppSettings.applicationName.value,
                  themeMode: themeMode,
                  theme: FluffyThemes.buildTheme(
                    context,
                    Brightness.light,
                    primaryColor,
                  ),
                  darkTheme: FluffyThemes.buildTheme(
                    context,
                    Brightness.dark,
                    primaryColor,
                  ),
                  scrollBehavior: CustomScrollBehavior(),
                  locale: context.watch<LocaleProvider>().locale,
                  localizationsDelegates: L10n.localizationsDelegates,
                  supportedLocales: L10n.supportedLocales,
                  routerConfig: FluffyChatApp.router,
                  builder: (context, child) => AppLockWidget(
                    pincode: widget.pincode,
                    clients: widget.clients,
                    child: Matrix(
                      clients: widget.clients,
                      store: widget.store,
                      child: widget.testWidget ?? child,
                    ),
                  ),
                );
        },
      ),
    );
  }
}
