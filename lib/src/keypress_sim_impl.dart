// cross_platform_key_emulator.dart
// A Dart:ffi implementation to emulate key presses on Windows, macOS, and Linux (X11)
library;

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Windows FFI types
typedef _SendInputNative = Uint32 Function(
    Uint32 nInputs, Pointer<INPUT> pInputs, Int32 cbSize);
typedef _SendInput = int Function(
    int nInputs, Pointer<INPUT> pInputs, int cbSize);

@Packed(1)
final class INPUT extends Struct {
  @Uint32()
  external int type;

  // Use a union to represent the input union in the C struct
  // We only care about keyboard input for this implementation
  @Uint16()
  external int wVk; // Virtual-key code
  @Uint16()
  external int wScan; // Hardware scan code
  @Uint32()
  external int dwFlags; // Various flags
  @Uint32()
  external int time; // Timestamp
  @IntPtr()
  external int dwExtraInfo; // Extra info from keybd_event

  // Add padding to match the C struct size
  @Uint64()
  external int padding1;
  @Uint64()
  external int padding2;
}

/// Common key identifiers across platforms.
enum Key {
  keyA,
  keyB,
  keyC,
  keyD,
  keyE,
  keyF,
  keyG,
  keyH,
  keyI,
  keyJ,
  keyK,
  keyL,
  keyM,
  keyN,
  keyO,
  keyP,
  keyQ,
  keyR,
  keyS,
  keyT,
  keyU,
  keyV,
  keyW,
  keyX,
  keyY,
  keyZ,
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  enter,
  escape,
  space,
  backspace,
  tab,
  shiftLeft,
  shiftRight,
  controlLeft,
  controlRight,
  altLeft,
  altRight,
  arrowLeft,
  arrowUp,
  arrowRight,
  arrowDown,
  windowsLeft,
  windowsRight, // Windows key on Windows, Super key on Linux
  commandLeft,
  commandRight, // Command key on macOS
}

/// A singleton class for sending synthetic key events and typing text.
class KeyEmulator {
  // Singleton instance
  static final KeyEmulator _instance = KeyEmulator._internal();
  factory KeyEmulator() => _instance;

  // Constants
  static const int keyEventFKeyUp = 0x0002;
  static const int _kCGHIDEventTap = 0;

  // Windows implementation
  late final DynamicLibrary _user32;
  late final _SendInput _sendInput;

  // macOS implementation
  late final DynamicLibrary _core;
  late final Pointer<Void> Function(Pointer<Void>, int, int)
      _cgEventCreateKeyboardEvent;
  late final void Function(int, Pointer<Void>) _cgEventPost;
  late final void Function(Pointer<Void>) _cfRelease;

  // Linux implementation
  late final DynamicLibrary _libX11;
  late final DynamicLibrary _libXtst;
  late final Pointer<Void> Function(Pointer<Utf8>) _xOpenDisplay;
  late final int Function(Pointer<Void>, int) _xKeysymToKeycode;
  late final int Function(Pointer<Void>, int, int, int) _xTestFakeKeyEvent;
  late final void Function(Pointer<Void>) _xFlush;
  Pointer<Void>? _display;

  // Initialize platform-specific functions
  KeyEmulator._internal() {
    if (Platform.isWindows) {
      _initWindowsFunctions();
    } else if (Platform.isMacOS) {
      _initMacFunctions();
    } else if (Platform.isLinux) {
      _initLinuxFunctions();
    }
  }

  void _initWindowsFunctions() {
    _user32 = DynamicLibrary.open('user32.dll');
    _sendInput = _user32.lookupFunction<_SendInputNative, _SendInput>(
      'SendInput',
    );
  }

  void _initMacFunctions() {
    _core = DynamicLibrary.process();
    _cgEventCreateKeyboardEvent = _core.lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint16, Uint8),
        Pointer<Void> Function(
            Pointer<Void>, int, int)>('CGEventCreateKeyboardEvent');
    _cgEventPost = _core.lookupFunction<Void Function(Uint32, Pointer<Void>),
        void Function(int, Pointer<Void>)>('CGEventPost');
    _cfRelease = _core.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('CFRelease');
  }

  DynamicLibrary _loadLibrary(String name, List<String> alternatives) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {
      for (final alt in alternatives) {
        try {
          return DynamicLibrary.open(alt);
        } catch (_) {
          // Try next alternative
        }
      }
      throw UnsupportedError('Failed to load library: $name');
    }
  }

  void _initLinuxFunctions() {
    _libX11 = _loadLibrary('libX11.so', ['libX11.so.6']);
    _libXtst = _loadLibrary('libXtst.so', ['libXtst.so.6']);

    _xOpenDisplay = _libX11.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('XOpenDisplay');
    _xKeysymToKeycode = _libX11.lookupFunction<
        Uint8 Function(Pointer<Void>, Uint64),
        int Function(Pointer<Void>, int)>('XKeysymToKeycode');
    _xTestFakeKeyEvent = _libXtst.lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Int32, Uint64),
        int Function(Pointer<Void>, int, int, int)>('XTestFakeKeyEvent');
    _xFlush = _libX11.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('XFlush');
  }

  /// Send a key event by [Key].
  void sendKeyByKey(Key key, {bool press = true}) {
    final code = _getKeyCode(key);
    _sendKey(code, press: press);
  }

  /// Send a key event by platform-specific key code.
  void sendKey(int keyCode, {bool press = true}) {
    _sendKey(keyCode, press: press);
  }

  void _sendKey(int keyCode, {bool press = true}) {
    if (Platform.isWindows) {
      _sendWindowsKey(keyCode, press);
    } else if (Platform.isMacOS) {
      _sendMacKey(keyCode, press);
    } else if (Platform.isLinux) {
      _sendLinuxKey(keyCode, press);
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Types a full [text] string, emulating each character with optional delay.
  Future<void> typeText(
    String text, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    for (var codeUnit in text.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      Key? key;
      bool shift = false;

      if (RegExp(r'[A-Za-z]').hasMatch(char)) {
        final upper = char.toUpperCase();
        key = Key.values.firstWhere(
          (k) => k.toString().split('.').last == 'key$upper',
          orElse: () => throw UnsupportedError('Unsupported letter: $char'),
        );
        shift = char.toUpperCase() == char;
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        key = Key.values.firstWhere(
          (k) => k.toString().split('.').last == 'digit$char',
          orElse: () => throw UnsupportedError('Unsupported digit: $char'),
        );
      } else if (char == ' ') {
        key = Key.space;
      } else {
        // Skip unsupported characters
        continue;
      }

      if (shift) sendKeyByKey(Key.shiftLeft, press: true);
      sendKeyByKey(key, press: true);
      sendKeyByKey(key, press: false);
      if (shift) sendKeyByKey(Key.shiftLeft, press: false);

      await Future.delayed(delay);
    }
  }

  void _sendWindowsKey(int keyCode, bool press) {
    if (!Platform.isWindows) return;

    final input = calloc<INPUT>();
    input.ref.type = 1; // INPUT_KEYBOARD
    input.ref.wVk = keyCode;
    input.ref.wScan = 0;
    input.ref.dwFlags = press ? 0 : keyEventFKeyUp;
    input.ref.time = 0;
    input.ref.dwExtraInfo = 0;

    _sendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);
  }

  void _sendMacKey(int keyCode, bool press) {
    if (!Platform.isMacOS) return;

    final event = _cgEventCreateKeyboardEvent(nullptr, keyCode, press ? 1 : 0);
    _cgEventPost(_kCGHIDEventTap, event);
    _cfRelease(event); // Release the event to prevent memory leaks
  }

  void _sendLinuxKey(int keyCode, bool press) {
    if (!Platform.isLinux) return;

    _display ??= _xOpenDisplay(nullptr);
    if (_display == nullptr) {
      throw UnsupportedError('Could not open X display');
    }
    _xTestFakeKeyEvent(_display!, keyCode, press ? 1 : 0, 0);
    _xFlush(_display!);
  }

  // Cleanup method to close X display when done
  void dispose() {
    if (Platform.isLinux && _display != null && _display != nullptr) {
      final closeDisplay = _libX11.lookupFunction<Void Function(Pointer<Void>),
          void Function(Pointer<Void>)>('XCloseDisplay');
      closeDisplay(_display!);
      _display = null;
    }
  }

  //========== Cross-platform Key Mapping ==========//
  static const Map<Key, int> _windowsKeyMapping = {
    Key.keyA: 0x41, Key.keyB: 0x42, Key.keyC: 0x43, Key.keyD: 0x44,
    Key.keyE: 0x45, Key.keyF: 0x46, Key.keyG: 0x47, Key.keyH: 0x48,
    Key.keyI: 0x49, Key.keyJ: 0x4A, Key.keyK: 0x4B, Key.keyL: 0x4C,
    Key.keyM: 0x4D, Key.keyN: 0x4E, Key.keyO: 0x4F, Key.keyP: 0x50,
    Key.keyQ: 0x51, Key.keyR: 0x52, Key.keyS: 0x53, Key.keyT: 0x54,
    Key.keyU: 0x55, Key.keyV: 0x56, Key.keyW: 0x57, Key.keyX: 0x58,
    Key.keyY: 0x59, Key.keyZ: 0x5A,
    Key.digit0: 0x30, Key.digit1: 0x31, Key.digit2: 0x32, Key.digit3: 0x33,
    Key.digit4: 0x34, Key.digit5: 0x35, Key.digit6: 0x36, Key.digit7: 0x37,
    Key.digit8: 0x38, Key.digit9: 0x39,
    Key.enter: 0x0D, Key.escape: 0x1B, Key.space: 0x20, Key.backspace: 0x08,
    Key.tab: 0x09,
    Key.shiftLeft: 0xA0, Key.shiftRight: 0xA1,
    Key.controlLeft: 0xA2, Key.controlRight: 0xA3,
    Key.altLeft: 0xA4, Key.altRight: 0xA5,
    Key.arrowLeft: 0x25, Key.arrowUp: 0x26,
    Key.arrowRight: 0x27, Key.arrowDown: 0x28,
    Key.windowsLeft: 0x5B, Key.windowsRight: 0x5C, // Windows keys
    Key.commandLeft: 0x5B,
    Key.commandRight: 0x5C, // Map Command to Windows keys
  };

  static const Map<Key, int> _macKeyMapping = {
    Key.keyA: 0x00, Key.keyS: 0x01, Key.keyD: 0x02, Key.keyF: 0x03,
    Key.keyH: 0x04, Key.keyG: 0x05, Key.keyZ: 0x06, Key.keyX: 0x07,
    Key.keyC: 0x08, Key.keyV: 0x09, Key.keyB: 0x0B, Key.keyQ: 0x0C,
    Key.keyW: 0x0D, Key.keyE: 0x0E, Key.keyR: 0x0F, Key.keyY: 0x10,
    Key.keyT: 0x11, Key.keyI: 0x22, Key.keyJ: 0x26, Key.keyK: 0x28,
    Key.keyL: 0x25, Key.keyM: 0x2E, Key.keyN: 0x2D, Key.keyO: 0x1F,
    Key.keyP: 0x23, Key.keyU: 0x20,
    Key.digit1: 0x12, Key.digit2: 0x13, Key.digit3: 0x14, Key.digit4: 0x15,
    Key.digit6: 0x16, Key.digit5: 0x17, Key.digit8: 0x1C, Key.digit7: 0x1A,
    Key.digit9: 0x19, Key.digit0: 0x1D,
    Key.enter: 0x24, Key.escape: 0x35, Key.space: 0x31, Key.backspace: 0x33,
    Key.tab: 0x30,
    Key.shiftLeft: 0x38, Key.shiftRight: 0x3C,
    Key.controlLeft: 0x3B, Key.controlRight: 0x3E,
    Key.altLeft: 0x3A, Key.altRight: 0x3D,
    Key.arrowLeft: 0x7B, Key.arrowUp: 0x7E,
    Key.arrowRight: 0x7C, Key.arrowDown: 0x7D,
    Key.commandLeft: 0x37,
    Key.commandRight: 0x36, // Command keys (macOS specific)
    Key.windowsLeft: 0x37,
    Key.windowsRight: 0x36, // Map Windows keys to Command keys on macOS
  };

  static const Map<Key, int> _linuxKeySymMapping = {
    Key.keyA: 0x0061, Key.keyB: 0x0062, Key.keyC: 0x0063, Key.keyD: 0x0064,
    Key.keyE: 0x0065, Key.keyF: 0x0066, Key.keyG: 0x0067, Key.keyH: 0x0068,
    Key.keyI: 0x0069, Key.keyJ: 0x006A, Key.keyK: 0x006B, Key.keyL: 0x006C,
    Key.keyM: 0x006D, Key.keyN: 0x006E, Key.keyO: 0x006F, Key.keyP: 0x0070,
    Key.keyQ: 0x0071, Key.keyR: 0x0072, Key.keyS: 0x0073, Key.keyT: 0x0074,
    Key.keyU: 0x0075, Key.keyV: 0x0076, Key.keyW: 0x0077, Key.keyX: 0x0078,
    Key.keyY: 0x0079, Key.keyZ: 0x007A,
    Key.digit0: 0x0030,
    Key.digit1: 0x0031,
    Key.digit2: 0x0032,
    Key.digit3: 0x0033,
    Key.digit4: 0x0034,
    Key.digit5: 0x0035,
    Key.digit6: 0x0036,
    Key.digit7: 0x0037,
    Key.digit8: 0x0038, Key.digit9: 0x0039,
    Key.enter: 0xFF0D, Key.escape: 0xFF1B, Key.space: 0x0020,
    Key.backspace: 0xFF08, Key.tab: 0xFF09,
    Key.shiftLeft: 0xFFE1, Key.shiftRight: 0xFFE2,
    Key.controlLeft: 0xFFE3, Key.controlRight: 0xFFE4,
    Key.altLeft: 0xFFE9, Key.altRight: 0xFFEA,
    Key.arrowLeft: 0xFF51, Key.arrowUp: 0xFF52,
    Key.arrowRight: 0xFF53, Key.arrowDown: 0xFF54,
    Key.windowsLeft: 0xFFEB,
    Key.windowsRight: 0xFFEC, // Super/Windows keys in X11
    Key.commandLeft: 0xFFEB,
    Key.commandRight: 0xFFEC, // Map Command keys to Super keys in Linux
  };

  int _getKeyCode(Key key) {
    if (Platform.isWindows) {
      return _windowsKeyMapping[key]!;
    } else if (Platform.isMacOS) {
      return _macKeyMapping[key]!;
    } else if (Platform.isLinux) {
      _display ??= _xOpenDisplay(nullptr);
      final sym = _linuxKeySymMapping[key]!;
      return _xKeysymToKeycode(_display!, sym);
    }
    throw UnsupportedError('Unsupported platform key mapping');
  }

  /// Sends a keyboard shortcut with multiple modifier keys in a way that ensures
  /// proper recognition by the operating system.
  ///
  /// [modifiers] should be provided in the order they should be pressed.
  /// The modifiers are released in reverse order after the [mainKey] is pressed.
  Future<void> sendShortcut(
    Key mainKey,
    List<Key> modifiers, {
    Duration keyPressDuration = const Duration(milliseconds: 100),
    Duration delayBetweenKeys = const Duration(milliseconds: 50),
    Duration finalDelay = const Duration(milliseconds: 200),
  }) async {
    try {
      // Press all modifier keys with brief delays between them
      for (final modifier in modifiers) {
        sendKeyByKey(modifier, press: true);
        await Future.delayed(delayBetweenKeys);
      }

      // Press and hold the main key briefly
      sendKeyByKey(mainKey, press: true);
      await Future.delayed(keyPressDuration);
      sendKeyByKey(mainKey, press: false);
      await Future.delayed(delayBetweenKeys);

      // Release modifier keys in reverse order
      for (final modifier in modifiers.reversed) {
        sendKeyByKey(modifier, press: false);
        await Future.delayed(delayBetweenKeys);
      }

      // Final delay to let the system process the entire shortcut
      await Future.delayed(finalDelay);
    } catch (e) {
      // Make sure all keys are released in case of an error
      for (final modifier in modifiers) {
        try {
          sendKeyByKey(modifier, press: false);
        } catch (_) {}
      }
      try {
        sendKeyByKey(mainKey, press: false);
      } catch (_) {}
      rethrow;
    }
  }
}
