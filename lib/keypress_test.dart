import 'package:keypress_test/keypress.dart';

int calculate() {
  final emul = KeyEmulator();
  emul.typeText('Hello world!');

  // emul.sendKeyByKey(Key.controlRight, press: true);
  return 0;
}
