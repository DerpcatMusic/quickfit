import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickfit/app.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/presentation/login_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoading: false);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots to login when unauthenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier()),
        ],
        child: const QuickfitApp(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Quickfit'), findsOneWidget);
  });
}
