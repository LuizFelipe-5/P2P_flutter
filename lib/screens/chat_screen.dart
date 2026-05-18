import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/connection_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(ConnectionProvider provider) {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    provider.sendTextMessage(text);
    _msgController.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile(ConnectionProvider provider) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      await provider.sendFile(file.path!, file.name);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0) {
            _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent);
          }
        });

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(provider),
                  const Divider(color: Color(0xFF21262D), height: 1),
                  Expanded(child: _buildMessages(provider)),
                  _buildInput(provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ConnectionProvider provider) {
    final connected =
        provider.connectionState == NearbyConnectionState.connected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              provider.disconnect();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF8B949E)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                connected ? const Color(0xFF238636) : const Color(0xFF6E7681),
                connected ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
              ]),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.connectedDeviceName.isNotEmpty
                      ? provider.connectedDeviceName
                      : 'Unknown Device',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? const Color(0xFF3FB950) : const Color(0xFF6E7681),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connected ? 'Connected' : 'Disconnected',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E)),
                  ),
                ]),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              provider.disconnect();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.power_settings_new_rounded,
                color: Color(0xFFE53935)),
            tooltip: 'Disconnect',
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(ConnectionProvider provider) {
    if (provider.messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56, color: const Color(0xFF30363D).withOpacity(0.6)),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF484F58))),
          const SizedBox(height: 4),
          Text('Send a message or file to get started',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF30363D))),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: provider.messages[i]),
    );
  }

  Widget _buildInput(ConnectionProvider provider) {
    final connected = provider.connectionState == NearbyConnectionState.connected;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Row(
        children: [
          // File button
          IconButton(
            onPressed: connected ? () => _pickAndSendFile(provider) : null,
            icon: const Icon(Icons.attach_file_rounded),
            color: const Color(0xFF58A6FF),
            disabledColor: const Color(0xFF30363D),
          ),
          const SizedBox(width: 4),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF21262D),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _msgController,
                enabled: connected,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: connected ? 'Type a message...' : 'Disconnected',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF484F58)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(provider),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: connected
                  ? const LinearGradient(colors: [Color(0xFF1F6FEB), Color(0xFF58A6FF)])
                  : null,
              color: connected ? null : const Color(0xFF21262D),
            ),
            child: IconButton(
              onPressed: connected ? () => _send(provider) : null,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              disabledColor: const Color(0xFF30363D),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isSystem = message.senderName == 'System';
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF21262D),
          ),
          child: Text(message.content,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E))),
        ),
      );
    }

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMe ? 16 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 16),
          ),
          gradient: message.isMe
              ? const LinearGradient(colors: [Color(0xFF1F6FEB), Color(0xFF388BFD)])
              : null,
          color: message.isMe ? null : const Color(0xFF21262D),
        ),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.file)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.insert_drive_file_rounded, size: 16,
                    color: message.isMe ? Colors.white70 : const Color(0xFF58A6FF)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(message.content,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
                ),
              ])
            else
              Text(message.content,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
