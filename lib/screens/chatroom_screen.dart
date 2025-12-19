import 'package:flutter/material.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String roomName;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  //  나중에 웹소켓/백엔드에서 받은 메시지로 교체
  final List<_ChatMessage> _messages = [
    _ChatMessage(text: '안녕하세요!', isMe: false, time: '10:01'),
    _ChatMessage(text: '오늘 러닝 가능해요?', isMe: false, time: '10:02'),
    _ChatMessage(text: '네! 몇 시가 좋으세요?', isMe: true, time: '10:03'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isMe: true, time: _nowHm()));
      _ctrl.clear();
    });

    // 전송 후 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    // 웹소켓 전송 연결 (roomId: widget.roomId)
  }

  String _nowHm() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(widget.roomName, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),


      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),

      body: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final m = _messages[i];
          return _MessageBubble(message: m);
        },
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final String time;

  _ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final rowAlign =
    message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: rowAlign,
            children: [
              if (!message.isMe) ...[
                const CircleAvatar(radius: 14),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isMe ? Colors.pinkAccent.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(fontSize: 14, height: 1.25),
                  ),
                ),
              ),
              if (message.isMe) ...[
                const SizedBox(width: 8),
                const CircleAvatar(radius: 14),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
