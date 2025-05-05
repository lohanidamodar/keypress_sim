import 'package:keypress_sim/keypress_sim.dart';
import 'dart:io';

void main() async {
  print('KeyPress Simulator Example');
  print('=========================');

  // Get an instance of the key emulator
  final emulator = KeyEmulator();

  // Wait to give user time to switch to a text editor or other application
  print('Waiting 3 seconds before simulating keyboard input...');
  print('Switch to your text editor or other application now!');
  await Future.delayed(Duration(seconds: 3));

  // Example 1: Type text
  print('Typing "Hello, World!"...');
  await emulator.typeText('Hello, World!');
  await Future.delayed(Duration(milliseconds: 500));

  // Simulate pressing Enter twice
  emulator.sendKeyByKey(Key.enter, press: true);
  await Future.delayed(Duration(milliseconds: 50));
  emulator.sendKeyByKey(Key.enter, press: false);
  await Future.delayed(Duration(milliseconds: 100));
  emulator.sendKeyByKey(Key.enter, press: true);
  await Future.delayed(Duration(milliseconds: 50));
  emulator.sendKeyByKey(Key.enter, press: false);

  // Example 2: Use shortcut methods
  print('Sending keyboard shortcuts...');

  // Send Ctrl+A (Command+A on macOS) to select all
  await emulator.sendShortcut(
      Key.keyA, [Platform.isMacOS ? Key.commandLeft : Key.controlLeft]);

  // Always remember to clean up resources when done
  emulator.dispose();

  print('Example completed!');
}
