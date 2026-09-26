import 'package:breath_and_insight_timer/main.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingFileSelector extends FileSelectorPlatform {
  List<XTypeGroup>? types;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    types = acceptedTypeGroups;
    return null;
  }
}

void main() {
  testWidgets(
    'iOS settings hide Android setup and use Apple file types',
    (tester) async {
      final originalSelector = FileSelectorPlatform.instance;
      final selector = _CapturingFileSelector();
      FileSelectorPlatform.instance = selector;
      addTearDown(() {
        FileSelectorPlatform.instance = originalSelector;
      });
      SharedPreferences.setMockInitialValues({
        'pranayamaRemoteControlEnabled': true,
      });
      await tester.pumpWidget(const BreathAndInsightTimerApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-tab-button')));
      await tester.pumpAndSettle();
      expect(find.text('Open Android remote input setup'), findsNothing);
      expect(find.text('Enable background timer support'), findsNothing);
      expect(find.text('Open background setup guide'), findsNothing);

      for (final entry in {
        'import-logs-button': ('csv', 'public.comma-separated-values-text'),
        'import-presets-button': ('json', 'public.json'),
      }.entries) {
        final button = find.byKey(ValueKey(entry.key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(selector.types!.single.extensions, [entry.value.$1]);
        // file_selector_ios rejects an extension-only filter before opening its
        // document picker. Keep both fields so Android/desktop also still work.
        expect(selector.types!.single.uniformTypeIdentifiers, [entry.value.$2]);
      }
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
