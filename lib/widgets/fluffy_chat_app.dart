import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/routes.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/config/locale_provider.dart';
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

  const FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
    // ← upstream: deep link + content URI redirect handler
    redirect: (context, state) {
      if (state.uri.scheme == 'content') return '/';
      if (state.uri.toString().startsWith(AppConfig.deepLinkPrefix)) {
        return '/rooms/newprivatechat#${state.uri}';
      }
      return null;
    },
  );

  @override
  State<FluffyChatApp> createState() => _FluffyChatAppState();
}

class _FluffyChatAppState extends State<FluffyChatApp> {
  bool _isRoot = false;
  String _rootText = '';

  Future<void> _processCheckJailbreakRoot() async {
    try {
      final isJailBroken = await JailbreakRootDetection.instance.isJailBroken;
      if (isJailBroken) {
        setState(() {
          _isRoot = true;
          _rootText = 'Your phone is rooted.';
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }

    // iOS-specific: also check bundle tampering
    if (Platform.isIOS && !_isRoot) {
      try {
        const bundleId = 'uz.uzinfocom.uchar';
        final isTampered =
        await JailbreakRootDetection.instance.isTampered(bundleId);
        if (isTampered) {
          setState(() {
            _isRoot = true;
            _rootText = 'Your phone is rooted.';
          });
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    _processCheckJailbreakRoot();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRoot) return CheckRoot(text: _rootText);

    return ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: ThemeBuilder(
        builder: (context, themeMode, primaryColor) => MaterialApp.router(
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
          // ← upstream: drives locale from LocaleProvider
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
        ),
      ),
    );
  }
}