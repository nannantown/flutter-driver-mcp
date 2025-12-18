import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_driver_mcp/flutter_driver_mcp.dart';

/// Custom MCP Server for Flutter Driver
/// Works around the bug in dart-lang/sdk#62265
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addOption('log-file', help: 'Path to log file for debugging');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('Flutter Driver MCP Server');
    print('');
    print('A custom MCP server for Flutter Driver that works around dart-lang/sdk#62265');
    print('');
    print('Usage: flutter_driver_mcp [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final logFile = results['log-file'] as String?;
  final server = McpServer(logFile: logFile);
  await server.run();
}
