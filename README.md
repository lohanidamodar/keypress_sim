# keypress_sim

A cross-platform keyboard input simulation package for Dart that works on Windows, macOS, and Linux using Dart ffi.

## Features

- Simulate keyboard input events across major desktop platforms
- Send individual key presses and releases
- Type text strings with configurable delays
- Send complex keyboard shortcuts with proper timing
- Platform-specific support for modifier keys (Control, Alt, Shift, Windows/Command)

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✓      |
| macOS    | ✓      |
| Linux    | ✓      |

## Installation

```yaml
dependencies:
  keypress_sim: ^0.1.0
```

## Usage

```dart
import 'package:keypress_sim/keypress_sim.dart';

void main() async {
  // Create an instance of KeyEmulator
  final keyEmulator = KeyEmulator();
  
  // Press and release a single key
  keyEmulator.sendKeyByKey(Key.keyA, press: true);
  keyEmulator.sendKeyByKey(Key.keyA, press: false);
  
  // Type text with automatic key presses
  await keyEmulator.typeText('Hello World!');
  
  // Send keyboard shortcuts
  await keyEmulator.sendCtrlShiftKey(Key.keyP); // Ctrl+Shift+P (Command+Shift+P on macOS)
  
  // Custom shortcuts with flexible timing
  await keyEmulator.sendShortcut(
    Key.keyS,
    [Key.controlLeft, Key.altLeft],
    keyPressDuration: Duration(milliseconds: 150),
    delayBetweenKeys: Duration(milliseconds: 70),
  );
  
  // Clean up resources when done (important for Linux/X11)
  keyEmulator.dispose();
}
```

## Platform-Specific Considerations

### Windows
Uses the Windows Input API via user32.dll to send virtual key events.

### macOS
Uses the CoreGraphics event system to create and post keyboard events.

### Linux
Uses X11 and XTest extension to simulate keyboard input. Requires the X11 development libraries to be installed:

```bash
# Ubuntu/Debian
sudo apt-get install libx11-dev libxtst-dev

# Fedora
sudo dnf install libX11-devel libXtst-devel
```

## Contributing

Contributions are welcome! Feel free to submit a Pull Request.

## License

This package is licensed under the MIT License - see the LICENSE file for details.
