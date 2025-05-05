import 'package:keypress_sim/keypress_sim.dart';
import 'package:test/test.dart';

void main() {
  group('KeyEmulator', () {
    test('KeyEmulator instance is singleton', () {
      final emulator1 = KeyEmulator();
      final emulator2 = KeyEmulator();
      expect(identical(emulator1, emulator2), isTrue);
    });

    test('Key enum contains expected values', () {
      // Test a few key values to ensure they exist
      expect(Key.values.contains(Key.keyA), isTrue);
      expect(Key.values.contains(Key.enter), isTrue);
      expect(Key.values.contains(Key.shiftLeft), isTrue);
      expect(Key.values.contains(Key.windowsLeft), isTrue);
      expect(Key.values.contains(Key.commandRight), isTrue);
    });
  });
}
