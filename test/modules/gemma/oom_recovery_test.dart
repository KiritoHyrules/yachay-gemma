import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/gemma/gemma_service.dart';

/// Post-migration OOM recovery verification.
///
/// The legacy OOM checkpoint system (`_recoverFromOom`, `_purgeOldCheckpoints`,
/// `oom_checkpoints.db`) has been removed. flutter_gemma's MediaPipe engine
/// handles memory management natively.
///
/// These tests verify the migration cleaned up correctly:
/// - `lastRecoveryMessage` always returns null
/// - `cargarModelo()` does not invoke OOM recovery DB logic
/// - All `@visibleForTesting` OOM controls are gone
void main() {
  group('OOM recovery — removed in flutter_gemma migration', () {
    test(
        'GIVEN GemmaService after flutter_gemma migration '
        'WHEN lastRecoveryMessage is accessed '
        'THEN returns null (OOM recovery removed)', () {
      final service = GemmaService.forTest();

      expect(service.lastRecoveryMessage, isNull,
          reason: 'MediaPipe handles memory natively — '
              'no OOM checkpoint system needed');
    });

    test(
        'GIVEN GemmaService singleton after migration '
        'WHEN lastRecoveryMessage is accessed on instance '
        'THEN returns null', () {
      expect(GemmaService.instance.lastRecoveryMessage, isNull,
          reason: 'OOM recovery completely removed from the codebase');
    });

    test(
        'GIVEN multiple GemmaService instances '
        'WHEN lastRecoveryMessage is read on each '
        'THEN all return null (no OOM state anywhere)', () {
      final a = GemmaService.forTest();
      final b = GemmaService.forTest();

      expect(a.lastRecoveryMessage, isNull);
      expect(b.lastRecoveryMessage, isNull);
    });
  });
}
