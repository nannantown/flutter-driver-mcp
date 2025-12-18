import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'flutter_driver_client.dart';

/// MCP Server implementation for Flutter Driver
class McpServer {
  final String? logFile;
  IOSink? _logSink;
  FlutterDriverClient? _driverClient;

  McpServer({this.logFile});

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _logSink?.writeln(logMessage);
    stderr.writeln(logMessage);
  }

  Future<void> run() async {
    if (logFile != null) {
      _logSink = File(logFile!).openWrite();
    }

    _log('Flutter Driver MCP Server starting...');

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
            'description': 'Take a screenshot of the app',
            'inputSchema': {
              'type': 'object',
              'properties': {},
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
            'description': 'Scroll a scrollable widget',
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
                  'description': 'Horizontal scroll delta',
                },
                'dy': {
                  'type': 'number',
                  'description': 'Vertical scroll delta',
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
      return {
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'content': [
            {
              'type': 'text',
              'text': 'Error: $e',
            },
          ],
          'isError': true,
        },
      };
    }
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
        return {
          'type': 'image',
          'data': base64Encode(bytes),
          'mimeType': 'image/png',
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
}
