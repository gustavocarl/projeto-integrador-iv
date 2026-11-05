import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/auth/presentation/controllers/auth_controller.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/features/settings/presentation/controllers/user_settings_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  test('logged out: defaults, without asking the backend', () async {
    final settings = FakeSettingsRepository()
      ..loadFailure = null
      ..settings = const UserSettings(requireProductImage: true);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(userSettingsProvider.future),
      UserSettings.defaults,
    );
  });

  test('loads the user\'s settings and resets them on logout', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(
            const UserSettings(createProductsOnImport: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(userSettingsProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(
      (await container.read(userSettingsProvider.future))
          .createProductsOnImport,
      isTrue,
    );

    await container.read(authControllerProvider.notifier).logout();

    expect(
      await container.read(userSettingsProvider.future),
      UserSettings.defaults,
    );
  });
}
