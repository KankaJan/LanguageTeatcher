import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/services/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPrefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = AppPrefs(await SharedPreferences.getInstance());
  });

  test('child pack switching is off until the parent enables it', () async {
    expect(prefs.childCanSwitchPacks, isFalse);

    await prefs.setChildCanSwitchPacks(true);
    expect(prefs.childCanSwitchPacks, isTrue);

    await prefs.setChildCanSwitchPacks(false);
    expect(prefs.childCanSwitchPacks, isFalse);
  });

  test('the toggle survives a reload of the preferences', () async {
    await prefs.setChildCanSwitchPacks(true);

    final reloaded = AppPrefs(await SharedPreferences.getInstance());
    expect(reloaded.childCanSwitchPacks, isTrue);
  });
}
