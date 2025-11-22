// 

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  runApp(const TownSqr());
}

class TownSqr extends StatelessWidget {
  const TownSqr({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Town Square',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1D29),
        primaryColor: const Color(0xFF6366F1),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, int> _postElementIndices = {};
  String _nickname = '';
  String _connectionStatus = 'Attempting to connect...';
  Color _statusColor = Colors.yellow;
  bool _isConnected = false;

  // Change this to your server IP address
  // ignore: constant_identifier_names
  static const String SERVER_URL = 'http://192.168.1.100:3000';

  @override
  void initState() {
    super.initState();
    _nickname = _generateNickname();
    _connectToServer();
  }

  String _generateNickname() {
    final adjectives = [
      'Curious',
      'Witty',
      'Silent',
      'Swift',
      'Bright',
      'Clever',
      'Agile',
      'Vivid',
    ];
    final nouns = [
      'Panda',
      'Eagle',
      'Octopus',
      'Raven',
      'Whale',
      'Llama',
      'Tiger',
      'Shark',
    ];
    final random = Random();
    final adj = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(900) + 100;
    return '$adj$noun-$number';
  }

  void _connectToServer() {
    socket = io.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      setState(() {
        _connectionStatus = 'Connected to the Global Feed!';
        _statusColor = const Color(0xFF10B981);
        _isConnected = true;
      });

      // Send join notification
      socket.emit('new_post', {
        'sender': 'System',
        'content': '$_nickname has entered the chat.',
        'isSystem': true,
      });
    });

    socket.on('initial_posts', (data) {
      if (data != null && data is List) {
        setState(() {
          for (var post in data) {
            final message = ChatMessage.fromJson(post, _nickname);
            _messages.add(message);
            if (message.id.isNotEmpty) {
              _postElementIndices[message.id] = _messages.length - 1;
            }
          }
        });
        _scrollToBottom();
      }
    });

    socket.on('new_post', (data) {
      setState(() {
        final message = ChatMessage.fromJson(data, _nickname);

        // If this is our own post, update the temporary post with real ID
        if (message.sender == _nickname && message.id.isNotEmpty) {
          // Find the most recent message from us without a real ID
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].sender == _nickname &&
                _messages[i].id.startsWith('temp-')) {
              _messages[i] = message;
              _postElementIndices[message.id] = i;
              return;
            }
          }
        } else if (message.sender != _nickname) {
          // Only add if it's from someone else
          _messages.add(message);
          if (message.id.isNotEmpty) {
            _postElementIndices[message.id] = _messages.length - 1;
          }
        }
      });
      _scrollToBottom();
    });

    socket.on('post_deleted', (postId) {
      setState(() {
        final index = _postElementIndices[postId];
        if (index != null && index < _messages.length) {
          _messages.removeAt(index);
          _postElementIndices.remove(postId);
          // Update all indices after the removed item
          for (var entry in _postElementIndices.entries.toList()) {
            if (entry.value > index) {
              _postElementIndices[entry.key] = entry.value - 1;
            }
          }
        }
      });
    });

    socket.onDisconnect((_) {
      setState(() {
        _connectionStatus =
            'Disconnected. Please restart the server.';
        _statusColor = const Color(0xFFEF4444);
        _isConnected = false;
      });
    });

    socket.onConnectError((error) {
      setState(() {
        _connectionStatus =
            'Connection Error: Check if server is running on $SERVER_URL';
        _statusColor = const Color(0xFFF59E0B);
        _isConnected = false;
      });
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && _isConnected) {
      final tempId =
          'temp-${DateTime.now().millisecondsSinceEpoch}-${Random().nextDouble()}';

      // Optimistic update - immediately show the message
      setState(() {
        _messages.add(
          ChatMessage(
            id: tempId,
            sender: _nickname,
            content: text,
            isSystem: false,
            isMyMessage: true,
          ),
        );
      });

      socket.emit('new_post', {
        'sender': _nickname,
        'content': text,
        'isSystem': false,
      });

      _controller.clear();
      _scrollToBottom();
    }
  }

  void _deletePost(String postId) {
    if (_isConnected && postId.isNotEmpty) {
      if (!postId.startsWith('temp-')) {
        socket.emit('delete_post', postId);
      } else {
        // For temporary posts, just remove from UI
        setState(() {
          _messages.removeWhere((msg) => msg.id == postId);
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
  void dispose() {
    socket.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32,
                horizontal: 16,
              ),
              child: Column(
                children: [
                  // Header
                  const Text(
                    'Town Square 🏛️💬',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF3F4F6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are connected as: $_nickname',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connection Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.2),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _connectionStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Messages Container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252836),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF374151),
                        ),
                      ),
                      child: _messages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Waiting for connection to server...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                return _MessageBubble(
                                  message: message,
                                  onDelete: () =>
                                      _deletePost(message.id),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input Form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252836),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: _isConnected,
                            decoration: InputDecoration(
                              hintText:
                                  'What\'s happening in the world?',
                              hintStyle: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1e2130),
                              border: OutlineInputBorder(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                borderSide: BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 2,
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFFF3F4F6),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isConnected
                              ? _sendMessage
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366f1),
                            disabledBackgroundColor: const Color(
                              0xFF3730A3,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Message data model
class ChatMessage {
  String id;
  final String sender;
  final String content;
  final bool isSystem;
  final bool isMyMessage;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.isSystem,
    required this.isMyMessage,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json,
    String myNickname,
  ) {
    final sender = json['sender'] ?? 'Unknown';
    final isSystem = json['isSystem'] ?? false;

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      sender: sender,
      content: json['content'] ?? '',
      isSystem: isSystem,
      isMyMessage: sender == myNickname && !isSystem,
    );
  }
}

// Message Bubble Widget
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onDelete;

  const _MessageBubble({
    required this.message,
    required this.onDelete,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color senderColor;
    String displaySender;

    if (widget.message.isSystem) {
      backgroundColor = const Color(0xFF1e2130);
      borderColor = const Color(0xFF374151).withValues(alpha: 0.5);
      textColor = const Color(0xFF9CA3AF);
      senderColor = const Color(0xFF9CA3AF);
      displaySender = 'System';
    } else if (widget.message.isMyMessage) {
      backgroundColor = const Color(0xFF6366f1).withValues(alpha: 0.2);
      borderColor = const Color(0xFF6366f1).withValues(alpha: 0.5);
      textColor = const Color(0xFFE5E7EB);
      senderColor = const Color(0xFF818CF8);
      displaySender = 'You';
    } else {
      backgroundColor = const Color(0xFF1e2130);
      borderColor = const Color(0xFF374151).withValues(alpha: 0.5);
      textColor = const Color(0xFFD1D5DB);
      senderColor = const Color(0xFFD1D5DB);
      displaySender = widget.message.sender;
    }

    return GestureDetector(
      onLongPress: widget.message.isMyMessage
          ? widget.onDelete
          : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$displaySender',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.message.isMyMessage
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: senderColor,
                      fontStyle: widget.message.isSystem
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message.content,
                    style: TextStyle(
                      fontSize: widget.message.isSystem ? 14 : 14,
                      color: textColor,
                      fontStyle: widget.message.isSystem
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
              if (widget.message.isMyMessage)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedValues(
                    Values: _isHovering ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onDelete,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFDC2626,
                            ).withValues(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
