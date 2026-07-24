import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'call_screen.dart';
import '../services/translation_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final String otherNumber;

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    required this.otherNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final TranslationService _translationService = TranslationService();

  String? _myUid;
  String _myLanguageCode = 'en';
  String _otherLanguageCode = 'en';
  String _chatId = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _setupChat();
  }

  Future<void> _setupChat() async {
    if (_myUid == null || widget.otherUid.trim().isEmpty) return;
if (_myUid == widget.otherUid.trim()) return;
    if (_myUid == null) return;

    final ids = [_myUid!, widget.otherUid]..sort();
    _chatId = ids.join('_');

    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();

      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .get();

      _myLanguageCode =
          (myDoc.data()?['preferredLanguageCode'] ?? 'en').toString();

      _otherLanguageCode =
          (otherDoc.data()?['preferredLanguageCode'] ?? 'en').toString();
    } catch (e) {
      debugPrint('Language load error: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendTextMessage() async {
    final text = _textCtrl.text.trim();

    if (text.isEmpty || _isSending || _myUid == null || _chatId.isEmpty) return;

    setState(() => _isSending = true);
    _textCtrl.clear();

    try {
      String translated = text;

      if (_myLanguageCode != _otherLanguageCode) {
        translated = await _translationService.translateText(
          text: text,
          sourceLanguage: _myLanguageCode,
          targetLanguage: _otherLanguageCode,
        );
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': _myUid,
        'type': 'text',
        'originalText': text,
        'translatedText': translated,
        'sourceLanguage': _myLanguageCode,
        'targetLanguage': _otherLanguageCode,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'participants': [_myUid, widget.otherUid],
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': _myUid,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      debugPrint('Send error: $e');
    }

    if (mounted) setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Color(0xFF1A1A2E),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
              ),
            ),
            child: Center(
              child: Text(
                widget.otherName.isNotEmpty
                    ? widget.otherName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.otherNumber,
                  style: const TextStyle(
                    color: Color(0xFF9B9B9B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF0E6FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.translate_rounded,
                color: Color(0xFF7B2FBE),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${_myLanguageCode.toUpperCase()} → ${_otherLanguageCode.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFF7B2FBE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  isCaller: true,
                  calleeUid: widget.otherUid,
                  callerUid: currentUid,
                ),
              ),
            );
          },
          icon: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
              ),
            ),
            child: const Icon(
              Icons.call_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_chatId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limitToLast(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs.where((doc) {
              final data = doc.data();
              return (data['type'] ?? 'text') == 'text';
            }).toList() ??
            [];

        if (docs.isEmpty) {
          return const Center(child: Text('Say Hello! 👋'));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isMe = data['senderId'] == _myUid;

            Widget? separator;
            if (index == 0) {
              separator = _buildDateSeparator(data['timestamp'] as Timestamp?);
            }

            return Column(
              children: [
                if (separator != null) separator,
                _buildTextBubble(data, isMe),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(Timestamp? ts) {
    if (ts == null) return const SizedBox.shrink();

    final dt = ts.toDate();
    final now = DateTime.now();

    final label =
        dt.day == now.day && dt.month == now.month && dt.year == now.year
            ? 'Today'
            : '${dt.day}/${dt.month}/${dt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> data, bool isMe) {
    final originalText = (data['originalText'] ?? '').toString();
    final translatedText = (data['translatedText'] ?? '').toString();
    final timestamp = data['timestamp'] as Timestamp?;

    final displayText = isMe ? originalText : translatedText;
    final subText = isMe ? translatedText : originalText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayText,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (subText.isNotEmpty && subText != displayText) ...[
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF7B2FBE),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.65)
                            : Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8D8F0)),
              ),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2D6B), Color(0xFFDA3AE8)],
                ),
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}