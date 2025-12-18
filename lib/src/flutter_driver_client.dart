import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client for communicating with Flutter Driver extension
class FlutterDriverClient {
  VmService? _vmService;
  String? _isolateId;
  bool _connected = false;

  bool get isConnected => _connected;

  /// Connect to Flutter app via VM Service URI
  Future<void> connect(String uri) async {
    // Convert http:// to ws:// if needed
    var wsUri = uri;
    if (uri.startsWith('http://')) {
      wsUri = uri.replaceFirst('http://', 'ws://');
    } else if (uri.startsWith('https://')) {
      wsUri = uri.replaceFirst('https://', 'wss://');
    }

    // Ensure URI ends with /ws
    if (!wsUri.endsWith('/ws')) {
      if (wsUri.endsWith('/')) {
        wsUri = '${wsUri}ws';
      } else {
        wsUri = '$wsUri/ws';
      }
    }

    _vmService = await vmServiceConnectUri(wsUri);

    // Get the main isolate
    final vm = await _vmService!.getVM();
    for (final isolate in vm.isolates ?? []) {
      if (isolate.name == 'main') {
        _isolateId = isolate.id;
        break;
      }
    }

    // If no 'main' isolate found, use the first one
    if (_isolateId == null && (vm.isolates?.isNotEmpty ?? false)) {
      _isolateId = vm.isolates!.first.id;
    }

    if (_isolateId == null) {
      throw Exception('No isolate found');
    }

    // Wait for Flutter Driver extension to be available
    await _waitForExtension();

    _connected = true;
  }

  Future<void> _waitForExtension() async {
    const maxAttempts = 30;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final result = await _callExtension('get_health', {});
        if (result['status'] == 'ok') {
          return;
        }
      } catch (e) {
        // Extension not ready yet
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw Exception('Flutter Driver extension not responding');
  }

  /// Disconnect from the Flutter app
  Future<void> disconnect() async {
    await _vmService?.dispose();
    _vmService = null;
    _isolateId = null;
    _connected = false;
  }

  /// Call Flutter Driver extension method
  Future<Map<String, dynamic>> _callExtension(
    String command,
    Map<String, dynamic> params,
  ) async {
    if (_vmService == null || _isolateId == null) {
      throw Exception('Not connected');
    }

    final args = {
      'command': command,
      ...params,
    };

    final response = await _vmService!.callServiceExtension(
      'ext.flutter.driver',
      isolateId: _isolateId,
      args: args,
    );

    if (response.json == null) {
      throw Exception('No response from Flutter Driver');
    }

    final result = response.json!;

    if (result['isError'] == true) {
      throw Exception(result['response'] ?? 'Unknown error');
    }

    return result;
  }

  /// Check health of Flutter Driver extension
  Future<Map<String, dynamic>> getHealth() async {
    return await _callExtension('get_health', {});
  }

  /// Tap on a widget
  Future<void> tap(Map<String, dynamic> finder, {Duration? timeout}) async {
    await _callExtension('tap', {
      ...finder,
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Enter text into focused text field
  Future<void> enterText(String text) async {
    await _callExtension('enter_text', {'text': text});
  }

  /// Get text from a widget
  Future<String> getText(Map<String, dynamic> finder, {Duration? timeout}) async {
    final result = await _callExtension('get_text', {
      ...finder,
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
    return result['text'] as String? ?? '';
  }

  /// Wait for a widget to appear
  Future<void> waitFor(Map<String, dynamic> finder, {Duration? timeout}) async {
    await _callExtension('waitFor', {
      ...finder,
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Wait for a widget to disappear
  Future<void> waitForAbsent(Map<String, dynamic> finder, {Duration? timeout}) async {
    await _callExtension('waitForAbsent', {
      ...finder,
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Take a screenshot
  Future<Uint8List> screenshot() async {
    final result = await _callExtension('screenshot', {});
    final base64Data = result['screenshot'] as String;
    return base64Decode(base64Data);
  }

  /// Scroll a scrollable widget
  Future<void> scroll(
    Map<String, dynamic> finder,
    double dx,
    double dy,
    Duration duration, {
    Duration? timeout,
  }) async {
    await _callExtension('scroll', {
      ...finder,
      'dx': dx.toString(),
      'dy': dy.toString(),
      'duration': duration.inMicroseconds.toString(),
      'frequency': '60',
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Scroll until a widget is visible
  Future<void> scrollIntoView(
    Map<String, dynamic> finder, {
    double alignment = 0.0,
    Duration? timeout,
  }) async {
    await _callExtension('scrollIntoView', {
      ...finder,
      'alignment': alignment.toString(),
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Wait for widget to be tappable
  Future<void> waitForTappable(Map<String, dynamic> finder, {Duration? timeout}) async {
    await _callExtension('waitForTappable', {
      ...finder,
      if (timeout != null) 'timeout': timeout.inMilliseconds.toString(),
    });
  }

  /// Get render tree diagnostics
  Future<Map<String, dynamic>> getRenderTree(Map<String, dynamic> finder) async {
    return await _callExtension('get_diagnostics_tree', {
      ...finder,
      'diagnosticsType': 'renderObject',
    });
  }

  /// Get widget tree diagnostics
  Future<Map<String, dynamic>> getWidgetTree(Map<String, dynamic> finder) async {
    return await _callExtension('get_diagnostics_tree', {
      ...finder,
      'diagnosticsType': 'widget',
    });
  }
}
