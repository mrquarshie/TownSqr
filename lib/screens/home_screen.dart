import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import '../models/user.dart';
import '../utils/constants.dart';
import '../widgets/post_widget.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late io.Socket _socket;
  final List<Post> _posts = [];
  final _messageController = TextEditingController();
  String _currentRoom = 'general';
  File? _selectedImage;
  bool _isConnected = false;
  String _connectionStatus = 'Attempting to connect...';

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  void _initSocket() {
    _socket = io.io(
      Constants.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      setState(() {
        _isConnected = true;
        _connectionStatus = 'Connected!';
      });
      _socket.emit('authenticate', {
        'username': widget.user.username,
      });
      _socket.emit('join_room', _currentRoom);
    });

    _socket.on('authenticated', (_) {
      debugPrint('Authenticated successfully');
    });

    _socket.on('auth_error', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Authentication failed'),
        ),
      );
    });

    _socket.on('initial_posts', (data) {
      setState(() {
        _posts.clear();
        for (var postJson in data) {
          _posts.add(Post.fromJson(postJson));
        }
        _posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    });

    _socket.on('new_post', (data) {
      if (data['room'] != _currentRoom && _currentRoom != 'general') {
        return;
      }
      setState(() {
        _posts.insert(0, Post.fromJson(data));
      });
    });

    _socket.on('post_replied', (data) {
      final postId = data['postId'];
      final reply = Reply.fromJson(data['reply']);
      setState(() {
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          final post = _posts[postIndex];
          _posts[postIndex] = Post(
            id: post.id,
            sender: post.sender,
            displayName: post.displayName,
            avatar: post.avatar,
            content: post.content,
            imageUrl: post.imageUrl,
            room: post.room,
            timestamp: post.timestamp,
            replies: [...post.replies, reply],
          );
        }
      });
    });

    _socket.on('post_deleted', (postId) {
      setState(() {
        _posts.removeWhere((p) => p.id == postId);
      });
    });

    _socket.on('error', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'An error occurred'),
        ),
      );
    });

    _socket.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Disconnected. Please refresh.';
      });
    });

    _socket.onConnectError((data) {
      setState(() {
        _isConnected = false;
        _connectionStatus =
            'Connection Error: Check if server is running';
      });
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.serverUrl}/api/upload-post-image'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = json.decode(
          await response.stream.bytesToString(),
        );
        return data['imageUrl'];
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
    return null;
  }

  Future<void> _submitPost() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
        return;
      }
    }

    _socket.emit('new_post', {
      'content': content,
      'imageUrl': imageUrl,
      'room': _currentRoom,
    });

    _messageController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  void _joinRoom(String room) {
    if (room != 'general' && room != widget.user.school) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only access General room and your school room',
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentRoom = room;
      _posts.clear();
    });
    _socket.emit('join_room', room);
  }

  void _deletePost(String postId) {
    _socket.emit('delete_post', {
      'postId': postId,
      'room': _currentRoom,
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('townsqr_user');
    _socket.disconnect();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Town Square'),
            const Spacer(),
            if (widget.user.avatar != null)
              CachedNetworkImage(
                imageUrl:
                    '${Constants.serverUrl}${widget.user.avatar}',
                imageBuilder: (context, imageProvider) =>
                    CircleAvatar(
                      backgroundImage: imageProvider,
                      radius: 20,
                    ),
                placeholder: (context, url) => const CircleAvatar(
                  radius: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  radius: 20,
                  child: Text(
                    widget.user.displayName[0].toUpperCase(),
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF667eea),
                child: Text(
                  widget.user.displayName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _logout,
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  '@${widget.user.displayName} • ${Constants.getSchoolName(widget.user.school)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isConnected
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _connectionStatus,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: Constants.rooms.map((room) {
                final isSelected = _currentRoom == room.value;
                final canAccess =
                    room.value == 'general' ||
                    room.value == widget.user.school;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${room.emoji} ${room.name}'),
                    selected: isSelected,
                    onSelected: canAccess
                        ? (selected) {
                            if (selected) _joinRoom(room.value);
                          }
                        : null,
                    selectedColor: const Color(0xFF667eea),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface,
                    disabledColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Current Room: ${Constants.getSchoolEmoji(_currentRoom)} ${Constants.getSchoolName(_currentRoom)}',
              style: const TextStyle(
                color: Color(0xFF667eea),
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "What's happening?",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        enabled: _isConnected,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isConnected ? _submitPost : null,
                      child: const Text('Post'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _isConnected ? _pickImage : null,
                      icon: const Icon(Icons.photo),
                      label: const Text('Add Photo'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          Image.file(
                            _selectedImage!,
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _posts.isEmpty
                ? const Center(
                    child: Text(
                      'No posts yet. Be the first to post!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return PostWidget(
                        post: _posts[index],
                        currentUsername: widget.user.username,
                        onDelete: _deletePost,
                        onReply: (postId, content, imageUrl) {
                          _socket.emit('reply_to_post', {
                            'postId': postId,
                            'content': content,
                            'imageUrl': imageUrl,
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8),
        color: Theme.of(context).colorScheme.surface,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Made with ❤️, charley.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              'est. 2025 by College Engineering',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
