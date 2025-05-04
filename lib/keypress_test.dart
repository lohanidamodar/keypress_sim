import 'package:keypress_test/keypress.dart';
import 'dart:io';
import 'dart:async';

Future<int> calculate() async {
  final emul = KeyEmulator();

  // Using the new shortcut helper method for Ctrl+Shift+P
  // This will automatically use Command+Shift+P on macOS
  // await emul.sendCtrlShiftKey(Key.keyP);

  // Alternative: use the more flexible sendShortcut method
  // if you need more control over timing parameters

  await emul.sendShortcut(
    Key.keyG,
    [Key.commandLeft, Key.controlLeft],
    keyPressDuration: Duration(milliseconds: 150),
    delayBetweenKeys: Duration(milliseconds: 70),
  );

  return 0;
}
