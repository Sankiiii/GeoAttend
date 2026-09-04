import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamController<dynamic>? _messageController;

  bool isConnected = false;

  Future<void> connect({
    required String accessToken,
    required String refreshToken,
  }) async {
    disconnect();

    _messageController = StreamController<dynamic>.broadcast();

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(
          'wss://svkmmembership.svkm.ac.in/apiuat/ws',
        ),
        headers: {
          'x-access-token': accessToken,
          'x-refresh-token': refreshToken,
        },
      );

      _subscription = _channel!.stream.listen(
        (message) {
          if (!isConnected) {
            isConnected = true;
            print('✅ SOCKET CONNECTED');
          }

          _messageController?.add(message);
          print('📨 MESSAGE => $message');
        },
        onError: (error) {
          _messageController?.addError(error);
          print('🚨 SOCKET ERROR => $error');
        },
        onDone: () {
          isConnected = false;
          _messageController?.close();
          print('⚪ SOCKET CLOSED');
        },
        cancelOnError: false,
      );

      print('🔄 ATTEMPTING SOCKET CONNECTION...');
    } catch (e) {
      _messageController?.addError(e);
      print('🚨 CONNECTION FAILED => $e');
    }
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(
        jsonEncode(data),
      );

      print('📤 SENT => $data');
    } catch (e) {
      print('🚨 SEND ERROR => $e');
    }
  }

  Stream<dynamic> get stream => _messageController?.stream ?? const Stream.empty();

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;

    _channel?.sink.close();
    _channel = null;

    _messageController?.close();
    _messageController = null;

    isConnected = false;
  }
}