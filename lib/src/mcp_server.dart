import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'flutter_driver_client.dart';

/// MCP Server implementation for Flutter Driver
class McpServer {
  final String? logFile;
  IOSink? _logSink;
  FlutterDriverClient? _driverClient;

  McpServer({this.logFile});

  void _log(String message) {
    // Logging disabled during stdio MCP transport
    // Uncomment for debugging: print to file directly
    // try {
    //   final timestamp = DateTime.now().toIso8601String();
    //   File('/tmp/flutter-driver-mcp.log').writeAsStringSync(
    //     '[$timestamp] $message\n',
    //     mode: FileMode.append,
    //   );
    // } catch (_) {}
  }

  Future<void> run() async {
    // Note: Logging disabled for stdio MCP transport compatibility

    // Listen for JSON-RPC messages on stdin
    final inputStream = stdin.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in inputStream) {
      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await _handleRequest(request);
        if (response != null) {
          stdout.writeln(jsonEncode(response));
        }
      } catch (e, st) {
        _log('Error processing request: $e\n$st');
        final errorResponse = {
          'jsonrpc': '2.0',
          'id': null,
          'error': {
            'code': -32700,
            'message': 'Parse error: $e',
          },
        };
        stdout.writeln(jsonEncode(errorResponse));
      }
    }
  }

  Future<Map<String, dynamic>?> _handleRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final id = request['id'];
    final params = request['params'] as Map<String, dynamic>? ?? {};

    _log('Received: $method');

    try {
      switch (method) {
        case 'initialize':
          return _handleInitialize(id, params);
        case 'initialized':
          return null; // Notification, no response
        case 'tools/list':
          return _handleToolsList(id);
        case 'tools/call':
          return await _handleToolsCall(id, params);
        case 'shutdown':
          await _driverClient?.disconnect();
          return {'jsonrpc': '2.0', 'id': id, 'result': null};
        default:
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32601,
              'message': 'Method not found: $method',
            },
          };
      }
    } catch (e, st) {
      _log('Error handling $method: $e\n$st');
      return {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': -32603,
          'message': 'Internal error: $e',
        },
      };
    }
  }

  Map<String, dynamic> _handleInitialize(dynamic id, Map<String, dynamic> params) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {},
        },
        'serverInfo': {
          'name': 'flutter-driver-mcp',
          'version': '1.0.0',
        },
      },
    };
  }

  Map<String, dynamic> _handleToolsList(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'tools': [
          {
            'name': 'connect',
            'description': 'Connect to a Flutter app via VM Service URI',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'uri': {
                  'type': 'string',
                  'description': 'VM Service WebSocket URI (e.g., ws://127.0.0.1:xxxxx/xxxxx=/ws)',
                },
              },
              'required': ['uri'],
            },
          },
          {
            'name': 'list_running_apps',
            'description': 'List running Flutter apps that can be connected to. Shows VM Service URIs for each app.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'disconnect',
            'description': 'Disconnect from the Flutter app',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'tap',
            'description': 'Tap on a widget',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Type of finder to use',
                },
                'text': {
                  'type': 'string',
                  'description': 'Text to find (for ByText finder)',
                },
                'key': {
                  'type': 'string',
                  'description': 'Key to find (for ByValueKey finder)',
                },
                'type': {
                  'type': 'string',
                  'description': 'Widget type to find (for ByType finder)',
                },
                'tooltip': {
                  'type': 'string',
                  'description': 'Tooltip message to find (for ByTooltipMessage finder)',
                },
                'timeout_ms': {
                  'type': 'integer',
                  'description': 'Timeout in milliseconds (default: 5000)',
                },
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'enter_text',
            'description': 'Enter text into a focused text field',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'text': {
                  'type': 'string',
                  'description': 'Text to enter',
                },
              },
              'required': ['text'],
            },
          },
          {
            'name': 'get_text',
            'description': 'Get text from a widget',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'wait_for',
            'description': 'Wait for a widget to appear',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'wait_for_absent',
            'description': 'Wait for a widget to disappear',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'screenshot',
            'description': 'Take a screenshot of the app. Consider using get_widget_tree instead to reduce context usage.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'max_dimension': {
                  'type': 'integer',
                  'description': 'Maximum width/height in pixels (default: 800, range: 200-2000). Smaller = less context.',
                },
                'format': {
                  'type': 'string',
                  'enum': ['png', 'jpeg'],
                  'description': 'Image format (default: png). JPEG is smaller but lossy.',
                },
                'quality': {
                  'type': 'integer',
                  'description': 'JPEG quality 1-100 (default: 80). Only used when format is jpeg.',
                },
              },
            },
          },
          {
            'name': 'get_health',
            'description': 'Check if Flutter Driver extension is responding',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'scroll',
            'description': 'Scroll a scrollable widget by delta values. Requires finding a scrollable widget first.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'dx': {
                  'type': 'number',
                  'description': 'Horizontal scroll delta (negative = scroll left, positive = scroll right)',
                },
                'dy': {
                  'type': 'number',
                  'description': 'Vertical scroll delta (negative = scroll up/reveal items below, positive = scroll down/reveal items above)',
                },
                'duration_ms': {
                  'type': 'integer',
                  'description': 'Duration in milliseconds (default: 500)',
                },
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type', 'dx', 'dy'],
            },
          },
          {
            'name': 'scroll_into_view',
            'description': 'Scroll until a widget becomes visible. This is the recommended way to scroll to off-screen widgets.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the TARGET widget to scroll into view',
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'alignment': {
                  'type': 'number',
                  'description': 'Where to align the widget (0.0 = top/left, 0.5 = center, 1.0 = bottom/right). Default: 0.0',
                },
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'scroll_until_visible',
            'description': 'Scroll a scrollable widget until a target widget becomes visible. Use this when scroll_into_view does not work.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'scrollable_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the SCROLLABLE widget (e.g., ListView, SingleChildScrollView)',
                },
                'scrollable_text': {'type': 'string'},
                'scrollable_key': {'type': 'string'},
                'scrollable_type': {'type': 'string'},
                'scrollable_tooltip': {'type': 'string'},
                'target_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the TARGET widget to find',
                },
                'target_text': {'type': 'string'},
                'target_key': {'type': 'string'},
                'target_type': {'type': 'string'},
                'target_tooltip': {'type': 'string'},
                'dy_per_scroll': {
                  'type': 'number',
                  'description': 'Vertical delta per scroll attempt (default: -300, negative scrolls down)',
                },
                'max_scrolls': {
                  'type': 'integer',
                  'description': 'Maximum number of scroll attempts (default: 10)',
                },
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['scrollable_finder_type', 'target_finder_type'],
            },
          },
          // === NEW TOOLS FOR CONTEXT OPTIMIZATION ===
          {
            'name': 'get_widget_tree',
            'description': 'Get the widget tree structure as compact text. Use this instead of screenshot for understanding app structure. Much smaller context footprint than screenshots.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Optional: Focus on a specific widget subtree. If not provided, returns from root.',
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'max_depth': {
                  'type': 'integer',
                  'description': 'Maximum depth of tree to return (default: 5, max: 20)',
                },
                'include_properties': {
                  'type': 'boolean',
                  'description': 'Include widget properties in output (default: false)',
                },
              },
            },
          },
          {
            'name': 'exists',
            'description': 'Instantly check if a widget exists. No waiting, returns immediately. Use for quick state verification.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'tap_no_wait',
            'description': 'Tap on a widget without waiting for the frame to settle. Use this when tapping opens dialogs or triggers animations that would cause timeout.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {
                  'type': 'integer',
                  'description': 'Timeout in milliseconds (default: 5000)',
                },
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'wait_for_tappable',
            'description': 'Wait for a widget to be tappable (visible and enabled). More reliable than wait_for for interactive elements.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {
                  'type': 'integer',
                  'description': 'Timeout in milliseconds (default: 10000)',
                },
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'long_press',
            'description': 'Long press on a widget for context menus or special interactions.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'timeout_ms': {
                  'type': 'integer',
                  'description': 'Timeout in milliseconds (default: 5000)',
                },
              },
              'required': ['finder_type'],
            },
          },
          {
            'name': 'tap_and_enter_text',
            'description': 'Tap on a text field and enter text in one operation. Combines tap + enter_text for efficiency.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                },
                'text': {'type': 'string', 'description': 'Text to find the field (for ByText finder)'},
                'key': {'type': 'string'},
                'type': {'type': 'string'},
                'tooltip': {'type': 'string'},
                'input_text': {
                  'type': 'string',
                  'description': 'Text to enter into the field',
                },
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['finder_type', 'input_text'],
            },
          },
          {
            'name': 'tap_and_wait_for',
            'description': 'Tap on a widget and wait for another widget to appear. Useful for button -> dialog flows.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'tap_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the widget to TAP',
                },
                'tap_text': {'type': 'string'},
                'tap_key': {'type': 'string'},
                'tap_type': {'type': 'string'},
                'tap_tooltip': {'type': 'string'},
                'wait_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the widget to WAIT FOR after tap',
                },
                'wait_text': {'type': 'string'},
                'wait_key': {'type': 'string'},
                'wait_type': {'type': 'string'},
                'wait_tooltip': {'type': 'string'},
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['tap_finder_type', 'wait_finder_type'],
            },
          },
          {
            'name': 'find_descendant',
            'description': 'Find a widget that is a descendant of another widget. Use for finding specific items in lists or containers.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'ancestor_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the ANCESTOR (parent/container) widget',
                },
                'ancestor_text': {'type': 'string'},
                'ancestor_key': {'type': 'string'},
                'ancestor_type': {'type': 'string'},
                'ancestor_tooltip': {'type': 'string'},
                'descendant_finder_type': {
                  'type': 'string',
                  'enum': ['ByText', 'ByValueKey', 'ByType', 'ByTooltipMessage'],
                  'description': 'Finder for the DESCENDANT widget to find',
                },
                'descendant_text': {'type': 'string'},
                'descendant_key': {'type': 'string'},
                'descendant_type': {'type': 'string'},
                'descendant_tooltip': {'type': 'string'},
                'action': {
                  'type': 'string',
                  'enum': ['tap', 'wait_for', 'get_text', 'exists'],
                  'description': 'Action to perform on the found widget (default: wait_for)',
                },
                'timeout_ms': {'type': 'integer'},
              },
              'required': ['ancestor_finder_type', 'descendant_finder_type'],
            },
          },
          // === DEVELOPMENT TOOLS (hot reload, errors, etc.) ===
          {
            'name': 'hot_reload',
            'description': 'Perform a hot reload of the Flutter app. Applies code changes without losing app state.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'hot_restart',
            'description': 'Perform a hot restart of the Flutter app. Resets app state completely but faster than full restart.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'get_runtime_errors',
            'description': 'Get any runtime errors or exceptions from the Flutter app.',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'get_app_state',
            'description': 'Get the current state of the connected Flutter app (isolate info, paused status, etc.).',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'set_widget_selection',
            'description': 'Enable or disable widget selection mode. When enabled, tapping in the app will select widgets for inspection.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'enabled': {
                  'type': 'boolean',
                  'description': 'Whether to enable widget selection mode',
                },
              },
              'required': ['enabled'],
            },
          },
          {
            'name': 'get_selected_widget',
            'description': 'Get information about the currently selected widget (when widget selection mode is enabled).',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
          {
            'name': 'resume',
            'description': 'Resume app execution if it is paused (e.g., on a breakpoint or exception).',
            'inputSchema': {
              'type': 'object',
              'properties': {},
            },
          },
        ],
      },
    };
  }

  Future<Map<String, dynamic>> _handleToolsCall(dynamic id, Map<String, dynamic> params) async {
    final toolName = params['name'] as String;
    final args = params['arguments'] as Map<String, dynamic>? ?? {};

    _log('Calling tool: $toolName with args: $args');

    try {
      final result = await _callTool(toolName, args);
      return {
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'content': [
            {
              'type': 'text',
              'text': result is String ? result : jsonEncode(result),
            },
          ],
        },
      };
    } catch (e) {
      final errorMessage = _formatErrorMessage(toolName, args, e);
      return {
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'content': [
            {
              'type': 'text',
              'text': errorMessage,
            },
          ],
          'isError': true,
        },
      };
    }
  }

  /// Find running Flutter apps by scanning for VM Service ports
  Future<List<Map<String, String>>> _findRunningFlutterApps() async {
    final apps = <Map<String, String>>[];

    try {
      // Use lsof to find Dart VM processes listening on ports
      final result = await Process.run('lsof', ['-i', '-P', '-n']);
      final output = result.stdout as String;

      // Look for Dart/Flutter VM service patterns
      final lines = output.split('\n');
      final portPattern = RegExp(r':(\d+)\s+\(LISTEN\)');

      for (final line in lines) {
        if (line.contains('dart') || line.contains('flutter')) {
          final match = portPattern.firstMatch(line);
          if (match != null) {
            final port = match.group(1);
            if (port != null) {
              // Try to get VM service info from this port
              try {
                final uri = 'ws://127.0.0.1:$port/ws';
                apps.add({
                  'uri': uri,
                  'port': port,
                  'process': line.split(RegExp(r'\s+'))[0],
                });
              } catch (_) {
                // Ignore ports that aren't VM services
              }
            }
          }
        }
      }
    } catch (e) {
      // lsof failed, try alternative method
      try {
        // Try to find Flutter processes
        final result = await Process.run('pgrep', ['-l', 'flutter']);
        if (result.exitCode == 0) {
          apps.add({
            'message': 'Flutter processes found. Check terminal for VM Service URI.',
            'hint': 'Look for: "A Dart VM Service on ... is available at: http://..."',
          });
        }
      } catch (_) {
        // Ignore
      }
    }

    return apps;
  }

  /// Format error message with helpful context
  String _formatErrorMessage(String toolName, Map<String, dynamic> args, Object error) {
    final buffer = StringBuffer();
    buffer.writeln('Error in $toolName:');

    final errorStr = error.toString();

    // Check for common error patterns and provide helpful suggestions
    if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
      buffer.writeln('  Widget not found within timeout.');
      buffer.writeln('');
      buffer.writeln('Suggestions:');
      buffer.writeln('  - Use get_widget_tree to see available widgets');
      buffer.writeln('  - Check if the widget is visible on screen');
      buffer.writeln('  - Try scroll_into_view if widget is off-screen');
      buffer.writeln('  - Increase timeout_ms if animation is slow');
      if (args['finder_type'] != null) {
        buffer.writeln('');
        buffer.writeln('Finder used:');
        buffer.writeln('  Type: ${args['finder_type']}');
        if (args['text'] != null) buffer.writeln('  Text: "${args['text']}"');
        if (args['key'] != null) buffer.writeln('  Key: "${args['key']}"');
        if (args['type'] != null) buffer.writeln('  WidgetType: "${args['type']}"');
        if (args['tooltip'] != null) buffer.writeln('  Tooltip: "${args['tooltip']}"');
      }
    } else if (errorStr.contains('Not connected')) {
      buffer.writeln('  Not connected to Flutter app.');
      buffer.writeln('');
      buffer.writeln('Solution:');
      buffer.writeln('  1. Ensure Flutter app is running with `flutter run`');
      buffer.writeln('  2. Copy the VM Service URI from console');
      buffer.writeln('  3. Call `connect` with the URI');
    } else if (errorStr.contains('Extension not responding')) {
      buffer.writeln('  Flutter Driver extension not responding.');
      buffer.writeln('');
      buffer.writeln('Solutions:');
      buffer.writeln('  1. Ensure app has `enableFlutterDriverExtension()` in test main');
      buffer.writeln('  2. Try restarting the app');
      buffer.writeln('  3. Check if another driver is connected');
    } else {
      buffer.writeln('  $errorStr');
    }

    return buffer.toString();
  }

  Future<dynamic> _callTool(String toolName, Map<String, dynamic> args) async {
    switch (toolName) {
      case 'connect':
        final uri = args['uri'] as String;
        _driverClient = FlutterDriverClient();
        await _driverClient!.connect(uri);
        return 'Connected to Flutter app';

      case 'disconnect':
        await _driverClient?.disconnect();
        _driverClient = null;
        return 'Disconnected';

      case 'list_running_apps':
        final apps = await _findRunningFlutterApps();
        if (apps.isEmpty) {
          return {
            'apps': [],
            'message': 'No Flutter apps found. Run your app with: flutter run',
          };
        }
        return {
          'apps': apps,
          'message': 'Found ${apps.length} Flutter app(s). Use connect with one of the URIs.',
        };

      case 'tap':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        await _driverClient!.tap(finder, timeout: timeout);
        return 'Tapped successfully';

      case 'enter_text':
        _ensureConnected();
        final text = args['text'] as String;
        await _driverClient!.enterText(text);
        return 'Text entered';

      case 'get_text':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        return await _driverClient!.getText(finder, timeout: timeout);

      case 'wait_for':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);
        await _driverClient!.waitFor(finder, timeout: timeout);
        return 'Widget found';

      case 'wait_for_absent':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);
        await _driverClient!.waitForAbsent(finder, timeout: timeout);
        return 'Widget is absent';

      case 'screenshot':
        _ensureConnected();
        final bytes = await _driverClient!.screenshot();
        final maxDim = args['max_dimension'] as int? ?? 800;
        final format = args['format'] as String? ?? 'png';
        final quality = args['quality'] as int? ?? 80;
        final resizedBytes = _resizeImage(bytes, maxDim, format, quality);
        return {
          'type': 'image',
          'data': base64Encode(resizedBytes),
          'mimeType': format == 'jpeg' ? 'image/jpeg' : 'image/png',
        };

      case 'get_health':
        _ensureConnected();
        final health = await _driverClient!.getHealth();
        return health;

      case 'scroll':
        _ensureConnected();
        final finder = _buildFinder(args);
        final dx = (args['dx'] as num).toDouble();
        final dy = (args['dy'] as num).toDouble();
        final duration = Duration(milliseconds: args['duration_ms'] as int? ?? 500);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        await _driverClient!.scroll(finder, dx, dy, duration, timeout: timeout);
        return 'Scrolled successfully';

      case 'scroll_into_view':
        _ensureConnected();
        final finder = _buildFinder(args);
        final alignment = (args['alignment'] as num?)?.toDouble() ?? 0.0;
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);
        await _driverClient!.scrollIntoView(finder, alignment: alignment, timeout: timeout);
        return 'Scrolled widget into view';

      case 'scroll_until_visible':
        _ensureConnected();
        final scrollableFinder = _buildFinderWithPrefix(args, 'scrollable_');
        final targetFinder = _buildFinderWithPrefix(args, 'target_');
        final dyPerScroll = (args['dy_per_scroll'] as num?)?.toDouble() ?? -300.0;
        final maxScrolls = args['max_scrolls'] as int? ?? 10;
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);

        // Try to find the target widget, scrolling if needed
        for (var i = 0; i < maxScrolls; i++) {
          try {
            // Check if target is already visible (with short timeout)
            await _driverClient!.waitFor(targetFinder, timeout: const Duration(milliseconds: 500));
            return 'Target widget found after $i scroll(s)';
          } catch (e) {
            // Target not visible yet, scroll
            try {
              await _driverClient!.scroll(
                scrollableFinder,
                0,
                dyPerScroll,
                const Duration(milliseconds: 300),
                timeout: timeout,
              );
              // Small delay for scroll animation
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (scrollError) {
              throw Exception('Failed to scroll: $scrollError');
            }
          }
        }
        throw Exception('Target widget not found after $maxScrolls scroll attempts');

      // === NEW TOOLS FOR CONTEXT OPTIMIZATION ===
      case 'get_widget_tree':
        _ensureConnected();
        final maxDepth = (args['max_depth'] as int? ?? 5).clamp(1, 20);
        final includeProperties = args['include_properties'] as bool? ?? false;

        Map<String, dynamic> finder;
        if (args['finder_type'] != null) {
          finder = _buildFinder(args);
        } else {
          // Use root finder if no finder specified
          finder = {'finderType': 'ByType', 'type': 'MaterialApp'};
        }

        final tree = await _driverClient!.getWidgetTree(
          finder,
          subtreeDepth: maxDepth,
          includeProperties: includeProperties,
        );
        return _summarizeWidgetTree(tree, maxDepth);

      case 'exists':
        _ensureConnected();
        final finder = _buildFinder(args);
        final exists = await _driverClient!.exists(finder);
        return {'exists': exists};

      case 'tap_no_wait':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        await _driverClient!.tapNoWait(finder, timeout: timeout);
        return 'Tapped (no wait)';

      case 'wait_for_tappable':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);
        await _driverClient!.waitForTappable(finder, timeout: timeout);
        return 'Widget is tappable';

      case 'long_press':
        _ensureConnected();
        final finder = _buildFinder(args);
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        await _driverClient!.longPress(finder, timeout: timeout);
        return 'Long pressed';

      case 'tap_and_enter_text':
        _ensureConnected();
        final finder = _buildFinder(args);
        final inputText = args['input_text'] as String;
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 5000);
        await _driverClient!.tap(finder, timeout: timeout);
        await Future.delayed(const Duration(milliseconds: 100));
        await _driverClient!.enterText(inputText);
        return 'Tapped and entered text';

      case 'tap_and_wait_for':
        _ensureConnected();
        final tapFinder = _buildFinderWithPrefix(args, 'tap_');
        final waitFinder = _buildFinderWithPrefix(args, 'wait_');
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);
        await _driverClient!.tapNoWait(tapFinder, timeout: timeout);
        await _driverClient!.waitFor(waitFinder, timeout: timeout);
        return 'Tapped and found expected widget';

      case 'find_descendant':
        _ensureConnected();
        final ancestorFinder = _buildFinderWithPrefix(args, 'ancestor_');
        final descendantFinder = _buildFinderWithPrefix(args, 'descendant_');
        final action = args['action'] as String? ?? 'wait_for';
        final timeout = Duration(milliseconds: args['timeout_ms'] as int? ?? 10000);

        // Build the combined Descendant finder
        final combinedFinder = FlutterDriverClient.buildDescendantFinder(
          ancestorFinder,
          descendantFinder,
        );

        switch (action) {
          case 'tap':
            await _driverClient!.tap(combinedFinder, timeout: timeout);
            return 'Tapped descendant widget';
          case 'get_text':
            final text = await _driverClient!.getText(combinedFinder, timeout: timeout);
            return {'text': text};
          case 'exists':
            final exists = await _driverClient!.exists(combinedFinder);
            return {'exists': exists};
          case 'wait_for':
          default:
            await _driverClient!.waitFor(combinedFinder, timeout: timeout);
            return 'Found descendant widget';
        }

      // === DEVELOPMENT TOOLS ===
      case 'hot_reload':
        _ensureConnected();
        final result = await _driverClient!.hotReload();
        return result;

      case 'hot_restart':
        _ensureConnected();
        final result = await _driverClient!.hotRestart();
        return result;

      case 'get_runtime_errors':
        _ensureConnected();
        final errors = await _driverClient!.getRuntimeErrors();
        return {
          'errors': errors,
          'count': errors.length,
          'message': errors.isEmpty ? 'No runtime errors' : '${errors.length} error(s) found',
        };

      case 'get_app_state':
        _ensureConnected();
        final state = await _driverClient!.getAppState();
        return state;

      case 'set_widget_selection':
        _ensureConnected();
        final enabled = args['enabled'] as bool;
        final result = await _driverClient!.setWidgetSelectionMode(enabled);
        return result;

      case 'get_selected_widget':
        _ensureConnected();
        final widget = await _driverClient!.getSelectedWidget();
        return widget;

      case 'resume':
        _ensureConnected();
        await _driverClient!.resume();
        return 'App resumed';

      default:
        throw Exception('Unknown tool: $toolName');
    }
  }

  void _ensureConnected() {
    if (_driverClient == null || !_driverClient!.isConnected) {
      throw Exception('Not connected to Flutter app. Call "connect" first.');
    }
  }

  Map<String, dynamic> _buildFinder(Map<String, dynamic> args) {
    final finderType = args['finder_type'] as String;

    switch (finderType) {
      case 'ByText':
        return {'finderType': 'ByText', 'text': args['text']};
      case 'ByValueKey':
        return {'finderType': 'ByValueKey', 'keyValueString': args['key'], 'keyValueType': 'String'};
      case 'ByType':
        return {'finderType': 'ByType', 'type': args['type']};
      case 'ByTooltipMessage':
        return {'finderType': 'ByTooltipMessage', 'text': args['tooltip']};
      default:
        throw Exception('Unknown finder type: $finderType');
    }
  }

  /// Build finder from args with a specific prefix (e.g., 'scrollable_' or 'target_')
  Map<String, dynamic> _buildFinderWithPrefix(Map<String, dynamic> args, String prefix) {
    final finderType = args['${prefix}finder_type'] as String;

    switch (finderType) {
      case 'ByText':
        return {'finderType': 'ByText', 'text': args['${prefix}text']};
      case 'ByValueKey':
        return {'finderType': 'ByValueKey', 'keyValueString': args['${prefix}key'], 'keyValueType': 'String'};
      case 'ByType':
        return {'finderType': 'ByType', 'type': args['${prefix}type']};
      case 'ByTooltipMessage':
        return {'finderType': 'ByTooltipMessage', 'text': args['${prefix}tooltip']};
      default:
        throw Exception('Unknown finder type: $finderType');
    }
  }

  /// Resize image and optionally convert format
  Uint8List _resizeImage(Uint8List bytes, int maxDimension, String format, int quality) {
    // Clamp values
    maxDimension = maxDimension.clamp(200, 2000);
    quality = quality.clamp(1, 100);

    final image = img.decodeImage(bytes);
    if (image == null) {
      return bytes;
    }

    // Calculate new dimensions maintaining aspect ratio
    int newWidth = image.width;
    int newHeight = image.height;

    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width > image.height) {
        newWidth = maxDimension;
        newHeight = (image.height * maxDimension / image.width).round();
      } else {
        newHeight = maxDimension;
        newWidth = (image.width * maxDimension / image.height).round();
      }
    }

    final resized = img.copyResize(image, width: newWidth, height: newHeight);

    // Encode to requested format
    if (format == 'jpeg') {
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Summarize widget tree to compact text format for reduced context usage
  String _summarizeWidgetTree(Map<String, dynamic> tree, int maxDepth) {
    final buffer = StringBuffer();
    _buildTreeString(tree, buffer, '', true, 0, maxDepth);
    return buffer.toString();
  }

  void _buildTreeString(
    Map<String, dynamic> node,
    StringBuffer buffer,
    String prefix,
    bool isLast,
    int depth,
    int maxDepth,
  ) {
    if (depth > maxDepth) return;

    // Extract widget info
    final description = node['description'] as String? ?? 'Unknown';
    final widgetType = _extractWidgetType(description);
    final properties = _extractKeyProperties(node);

    // Build line
    final connector = isLast ? '└─' : '├─';
    final line = depth == 0 ? widgetType : '$prefix$connector$widgetType';

    if (properties.isNotEmpty) {
      buffer.writeln('$line[$properties]');
    } else {
      buffer.writeln(line);
    }

    // Process children
    final children = node['children'] as List<dynamic>? ?? [];
    final newPrefix = depth == 0 ? '' : '$prefix${isLast ? '  ' : '│ '}';

    for (var i = 0; i < children.length; i++) {
      final child = children[i] as Map<String, dynamic>;
      _buildTreeString(child, buffer, newPrefix, i == children.length - 1, depth + 1, maxDepth);
    }
  }

  String _extractWidgetType(String description) {
    // Extract widget type from description like "Scaffold" or "Text('Hello')"
    final match = RegExp(r'^(\w+)').firstMatch(description);
    return match?.group(1) ?? description;
  }

  String _extractKeyProperties(Map<String, dynamic> node) {
    final props = <String>[];

    // Try to get key
    final valueKey = node['valueKey'];
    if (valueKey != null && valueKey.toString().isNotEmpty) {
      props.add('key: $valueKey');
    }

    // Try to get text content from description
    final description = node['description'] as String? ?? '';
    final textMatch = RegExp(r'"([^"]*)"').firstMatch(description);
    if (textMatch != null) {
      final text = textMatch.group(1);
      if (text != null && text.length <= 30) {
        props.add('text: "$text"');
      } else if (text != null) {
        props.add('text: "${text.substring(0, 27)}..."');
      }
    }

    // Try to get tooltip
    final tooltip = node['tooltip'];
    if (tooltip != null && tooltip.toString().isNotEmpty) {
      props.add('tooltip: $tooltip');
    }

    return props.join(', ');
  }
}
