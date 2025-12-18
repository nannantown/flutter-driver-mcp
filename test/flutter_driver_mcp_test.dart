import 'package:flutter_driver_mcp/flutter_driver_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpServer', () {
    test('can be instantiated', () {
      final server = McpServer();
      expect(server, isNotNull);
    });
  });

  group('FlutterDriverClient', () {
    test('can be instantiated', () {
      final client = FlutterDriverClient();
      expect(client, isNotNull);
      expect(client.isConnected, isFalse);
    });
  });
}
