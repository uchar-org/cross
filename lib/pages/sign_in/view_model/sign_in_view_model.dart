import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/pages/sign_in/view_model/flows/sort_homeservers.dart';
import 'package:fluffychat/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:fluffychat/pages/sign_in/view_model/sign_in_state.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/widgets.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class SignInViewModel extends ValueNotifier<SignInState> {
  final MatrixState matrixService;
  final bool signUp;
  final TextEditingController filterTextController = TextEditingController();

  SignInViewModel(this.matrixService, {required this.signUp})
    : super(SignInState()) {
    refreshPublicHomeservers();
    filterTextController.addListener(_filterHomeservers);
  }

  @override
  void dispose() {
    filterTextController.removeListener(_filterHomeservers);
    super.dispose();
  }

  void _filterHomeservers() {
    final filterText = filterTextController.text.trim().toLowerCase();
    final filteredPublicHomeservers =
        value.publicHomeservers.data
            ?.where(
              (homeserver) =>
                  homeserver.name?.toLowerCase().contains(filterText) ?? false,
            )
            .toList() ??
        [];
    final splitted = filterText.split('.');
    if (splitted.length >= 2 && !splitted.any((part) => part.isEmpty)) {
      if (!filteredPublicHomeservers.any(
        (homeserver) => homeserver.name == filterText,
      )) {
        filteredPublicHomeservers.add(PublicHomeserverData(name: filterText));
      }
    }
    value = value.copyWith(
      filteredPublicHomeservers: filteredPublicHomeservers,
    );
  }

  void refreshPublicHomeservers() async {
    value = value.copyWith(publicHomeservers: AsyncSnapshot.waiting());
    final defaultHomeserverData = PublicHomeserverData(
      name: AppSettings.defaultHomeserver.value,
    );

    try {
      var publicHomeservers = <PublicHomeserverData>[];

      if (!kIsWeb) {
        // Native: Matrix SDK clientini ishlatish (avvalgidek)
        final client = await matrixService.getLoginClient();
        final response = await client.httpClient.get(AppConfig.homeserverList);
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final homeserverJsonList = json['public_servers'] as List;
        publicHomeservers = homeserverJsonList
            .map((json) => PublicHomeserverData.fromJson(json))
            .toList();
      }
      // Web'da: faqat default server bilan ishlash (CORS muammosi)
      // yoki o'zingizning proxy serveringizdan olish

      if (signUp) {
        publicHomeservers.removeWhere((server) => server.regMethod == null);
      }

      publicHomeservers.sort(sortHomeservers);

      final defaultServer =
          publicHomeservers.singleWhereOrNull(
            (server) => server.name == AppSettings.defaultHomeserver.value,
          ) ??
          defaultHomeserverData;

      publicHomeservers.insert(0, defaultServer);

      Logs().i("Public homeservers count: ${publicHomeservers.length}");

      value = value.copyWith(
        selectedHomeserver: value.selectedHomeserver ?? publicHomeservers.first,
        publicHomeservers: AsyncSnapshot.withData(
          ConnectionState.done,
          publicHomeservers,
        ),
      );
    } catch (e, s) {
      Logs().w('Unable to fetch public homeservers...', e, s);
      value = value.copyWith(
        selectedHomeserver: defaultHomeserverData,
        publicHomeservers: AsyncSnapshot.withData(
          ConnectionState.done,
          [defaultHomeserverData],
        ),
      );
    }

    _filterHomeservers();
  }

  void selectHomeserver(PublicHomeserverData? publicHomeserverData) {
    value = value.copyWith(selectedHomeserver: publicHomeserverData);
  }

  void setLoginLoading(AsyncSnapshot<bool> loginLoading) {
    value = value.copyWith(loginLoading: loginLoading);
  }
}
