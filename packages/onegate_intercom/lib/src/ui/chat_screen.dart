import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onegate_feature_core/onegate_feature_core.dart';

import '../i18n/intercom_i18n.dart';
import '../models/room.dart';
import '../models/room_message.dart';
import '../services/chat_websocket_service.dart';
import '../services/room_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.host,
    required this.ctx,
    required this.room,
  });

  final FeatureHost host;
  final SocietyContext ctx;
  final Room room;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  bool _loading = true;
  String? _error;
  List<RoomMessage> _messages = const [];

  late final RoomService _roomService = RoomService.fromHost(widget.host);
  late final ChatWebSocketService _ws =
      ChatWebSocketService.fromHost(widget.host);

  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _connectWs();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws.disconnect();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connectWs() async {
    await _ws.connect(roomId: widget.room.id);
    _wsSub = _ws.messages.listen((event) {
      final type = (event['type'] ?? event['message_type'])?.toString();
      if (type == null) return;
      if (type.toLowerCase() == 'message') {
        final data = event['data'];
        if (data is Map<String, dynamic>) {
          final msg = RoomMessage.fromJson(data);
          if (!mounted) return;
          setState(() => _messages = [..._messages, msg]);
        } else if (data is Map) {
          final msg = RoomMessage.fromJson(Map<String, dynamic>.from(
              data.map((k, v) => MapEntry(k.toString(), v))));
          if (!mounted) return;
          setState(() => _messages = [..._messages, msg]);
        }
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await _roomService.getMessages(
        roomId: widget.room.id,
        companyId: widget.ctx.societyId,
      );
      if (!mounted) return;
      setState(() => _messages = msgs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _ws.sendText(roomId: widget.room.id, content: text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          intercomTr(
                            context,
                            'chatCall_failedWithError',
                            fallback: 'Failed: $_error',
                            params: {'error': _error ?? ''},
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final mine = m.userId == widget.ctx.userId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Colors.blue.withValues(alpha: 26)
                                    : Colors.grey.withValues(alpha: 26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(m.content),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: intercomTr(
                          context,
                          'chatCall_messageHint',
                          fallback: 'Message',
                        ),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
