import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../models/user.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

class PostWidget extends StatefulWidget {
  final Post post;
  final String currentUsername;
  final Function(String) onDelete;
  final Function(String, String, String?) onReply;

  const PostWidget({
    super.key,
    required this.post,
    required this.currentUsername,
    required this.onDelete,
    required this.onReply,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool _showReplyForm = false;
  final _replyController = TextEditingController();
  File? _replyImage;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _pickReplyImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _replyImage = File(pickedFile.path);
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

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty && _replyImage == null) return;

    String? imageUrl;
    if (_replyImage != null) {
      imageUrl = await _uploadImage(_replyImage!);
      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
        return;
      }
    }

    widget.onReply(widget.post.id, content, imageUrl);
    _replyController.clear();
    setState(() {
      _showReplyForm = false;
      _replyImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwnPost = widget.post.sender == widget.currentUsername;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e2130),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.post.avatar != null)
                CachedNetworkImage(
                  imageUrl:
                      '${Constants.serverUrl}${widget.post.avatar}',
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
                    backgroundColor: const Color(0xFF667eea),
                    child: Text(
                      widget.post.displayName[0].toUpperCase(),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF667eea),
                  child: Text(
                    widget.post.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOwnPost
                              ? 'You'
                              : '@${widget.post.displayName}',
                          style: TextStyle(
                            color: isOwnPost
                                ? const Color(0xFF667eea)
                                : Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimeUtils.formatTimestamp(
                            widget.post.timestamp,
                          ),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (widget.post.content.isNotEmpty)
                      Text(
                        widget.post.content,
                        style: const TextStyle(color: Colors.white),
                      ),
                    if (widget.post.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl:
                              '${Constants.serverUrl}${widget.post.imageUrl}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              Container(
                                height: 200,
                                color: Colors.grey[800],
                                child: const Icon(Icons.error),
                              ),
                        ),
                      ),
                    ],
                    if (widget.post.replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      ...widget.post.replies.map(
                        (reply) => _buildReply(reply),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showReplyForm = !_showReplyForm;
                        });
                      },
                      icon: const Icon(Icons.comment, size: 16),
                      label: const Text('Reply'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF667eea),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    if (_showReplyForm) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      TextField(
                        controller: _replyController,
                        decoration: const InputDecoration(
                          hintText: 'Write a reply...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pickReplyImage,
                            icon: const Icon(Icons.photo, size: 16),
                            label: const Text('Image'),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _submitReply,
                            child: const Text('Reply'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showReplyForm = false;
                                _replyImage = null;
                                _replyController.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      if (_replyImage != null) ...[
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Image.file(
                              _replyImage!,
                              height: 80,
                              width: 80,
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
                                    _replyImage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (isOwnPost)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    widget.onDelete(widget.post.id);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReply(Reply reply) {
    final isOwnReply = reply.sender == widget.currentUsername;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.avatar != null)
            CachedNetworkImage(
              imageUrl: '${Constants.serverUrl}${reply.avatar}',
              imageBuilder: (context, imageProvider) => CircleAvatar(
                backgroundImage: imageProvider,
                radius: 16,
              ),
              placeholder: (context, url) => const CircleAvatar(
                radius: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF667eea),
                child: Text(
                  reply.displayName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF667eea),
              child: Text(
                reply.displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOwnReply ? 'You' : '@${reply.displayName}',
                      style: TextStyle(
                        color: isOwnReply
                            ? const Color(0xFF667eea)
                            : Colors.grey[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      TimeUtils.formatTimestamp(reply.timestamp),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (reply.content.isNotEmpty)
                  Text(
                    reply.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                if (reply.imageUrl != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl:
                          '${Constants.serverUrl}${reply.imageUrl}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 100,
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 100,
                        color: Colors.grey[800],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
