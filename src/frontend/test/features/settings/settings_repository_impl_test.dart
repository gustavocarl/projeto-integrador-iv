import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';

import '../../helpers/fakes.dart';

SettingsRepositoryImpl _repository(FakeHttpAdapter adapter) =>
    SettingsRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );

void main() {
  test('get reads the logged-in user\'s settings', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'requireProductImage': true,
          'createProductsOnImport': false,
          'theme': 'Light',
        },
      ),
    );

    final settings = await _repository(adapter).get();

    final request = adapter.requests.single;
    expect((request.method, request.path), ('GET', '/api/settings'));
    expect(
      settings,
      const UserSettings(
        requireProductImage: true,
        theme: ThemePreference.light,
      ),
    );
  });

  test('update sends the theme by its API name', () async {
    final adapter = FakeHttpAdapter((_) => (200, {'theme': 'Light'}));

    final saved = await _repository(adapter)
        .update(theme: ThemePreference.light);

    expect(adapter.requests.single.data, {'theme': 'Light'});
    expect(saved.theme, ThemePreference.light);
  });

  test('an unknown or missing theme is dark', () {
    expect(ThemePreference.parse(null), ThemePreference.dark);
    expect(ThemePreference.parse('Blue'), ThemePreference.dark);
  });

  test('update sends only the options given', () async {
    final adapter = FakeHttpAdapter(
      (_) =>
          (200, {'requireProductImage': true, 'createProductsOnImport': true}),
    );

    final saved = await _repository(adapter)
        .update(createProductsOnImport: true);

    final request = adapter.requests.single;
    expect((request.method, request.path), ('PUT', '/api/settings'));
    expect(request.data, {'createProductsOnImport': true});
    expect(
      saved,
      const UserSettings(
        requireProductImage: true,
        createProductsOnImport: true,
      ),
    );
  });

  test(
    'restock warnings: on when the backend does not say, sent when changed',
    () async {
      expect(
        await _repository(FakeHttpAdapter((_) => (200, <String, dynamic>{})))
            .get(),
        const UserSettings(notifyRestock: true),
      );

      final adapter = FakeHttpAdapter((_) => (200, {'notifyRestock': false}));
      final saved = await _repository(adapter).update(notifyRestock: false);

      expect(adapter.requests.single.data, {'notifyRestock': false});
      expect(saved.notifyRestock, isFalse);
    },
  );
}
