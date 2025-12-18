# Flutter Driver MCP Server

A custom MCP (Model Context Protocol) server for Flutter Driver that works around [dart-lang/sdk#62265](https://github.com/dart-lang/sdk/issues/62265).

## Background

The built-in `dart mcp-server` has a bug where Flutter Driver commands fail with:
```
type 'int' is not a subtype of type 'String?' in type cast
```

This package provides a standalone MCP server that correctly handles Flutter Driver operations.

## Installation

```bash
# Clone the repository
git clone https://github.com/nannantown/flutter-driver-mcp.git

# Install globally
cd flutter-driver-mcp
dart pub global activate --source path .
```

Or add to your `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_driver_mcp:
    git:
      url: https://github.com/nannantown/flutter-driver-mcp.git
```

## MCP Configuration

Add to your MCP settings (e.g., `~/.config/claude/settings.json`):

```json
{
  "mcpServers": {
    "flutter-driver": {
      "command": "flutter_driver_mcp",
      "args": []
    }
  }
}
```

Or if running from source:
```json
{
  "mcpServers": {
    "flutter-driver": {
      "command": "dart",
      "args": ["run", "--enable-vm-service", "/path/to/flutter-driver-mcp/bin/server.dart"]
    }
  }
}
```

## Preparing Your Flutter App

Your Flutter app must have Flutter Driver extension enabled. Add to your `main.dart`:

```dart
import 'package:flutter_driver/driver_extension.dart';

void main() {
  enableFlutterDriverExtension();
  runApp(const MyApp());
}
```

Or create a separate entry point for testing (e.g., `test_driver/app.dart`):

```dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:your_app/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
```

Run your app with:
```bash
flutter run --target=test_driver/app.dart
```

Note the VM Service URI in the console output (e.g., `http://127.0.0.1:50300/xxxxx=/`).

## Available Tools

### connect
Connect to a Flutter app via VM Service URI.
```json
{
  "uri": "ws://127.0.0.1:50300/xxxxx=/ws"
}
```

### disconnect
Disconnect from the Flutter app.

### tap
Tap on a widget.
```json
{
  "finder_type": "ByText",
  "text": "Login"
}
```

Finder types:
- `ByText` - Find by displayed text
- `ByValueKey` - Find by widget key
- `ByType` - Find by widget type
- `ByTooltipMessage` - Find by tooltip

### enter_text
Enter text into a focused text field.
```json
{
  "text": "Hello World"
}
```

### get_text
Get text from a widget.
```json
{
  "finder_type": "ByValueKey",
  "key": "username_field"
}
```

### wait_for
Wait for a widget to appear.
```json
{
  "finder_type": "ByText",
  "text": "Welcome",
  "timeout_ms": 10000
}
```

### wait_for_absent
Wait for a widget to disappear.
```json
{
  "finder_type": "ByType",
  "type": "CircularProgressIndicator",
  "timeout_ms": 10000
}
```

### screenshot
Take a screenshot of the app. Returns base64-encoded PNG image.

### get_health
Check if Flutter Driver extension is responding.

### scroll
Scroll a scrollable widget.
```json
{
  "finder_type": "ByType",
  "type": "ListView",
  "dx": 0,
  "dy": -300,
  "duration_ms": 500
}
```

## Debugging

Enable logging to a file:
```bash
flutter_driver_mcp --log-file=/tmp/flutter_driver_mcp.log
```

## License

MIT License

## Related Issues

- [dart-lang/sdk#62265](https://github.com/dart-lang/sdk/issues/62265) - Flutter Driver MCP type cast bug
