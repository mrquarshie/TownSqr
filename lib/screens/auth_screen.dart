import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../models/user.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  String? _selectedSchool;
  File? _avatarFile;
  String _usernameStatus = '';
  bool _isUsernameAvailable = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.length < 3) {
      setState(() {
        _usernameStatus = 'Username must be at least 3 characters';
        _isUsernameAvailable = false;
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        _usernameStatus = 'Username must be less than 20 characters';
        _isUsernameAvailable = false;
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username.toLowerCase())) {
      setState(() {
        _usernameStatus =
            'Only letters, numbers, and underscores allowed';
        _isUsernameAvailable = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${Constants.serverUrl}/api/check-username/${username.toLowerCase()}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _usernameStatus = data['message'];
          _isUsernameAvailable = data['available'];
        });
      }
    } catch (e) {
      setState(() {
        _usernameStatus = 'Error checking username';
        _isUsernameAvailable = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _register() async {
    if (!_isUsernameAvailable || _selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Register user
      final response = await http.post(
        Uri.parse('${Constants.serverUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text.trim(),
          'school': _selectedSchool,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(json.decode(response.body)['error']);
      }

      final data = json.decode(response.body);
      final user = User.fromJson(data['user']);

      // Upload avatar if selected
      if (_avatarFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.serverUrl}/api/upload-avatar'),
        );
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            _avatarFile!.path,
          ),
        );
        request.fields['username'] = user.username;

        final avatarResponse = await request.send();
        if (avatarResponse.statusCode == 200) {
          final avatarData = json.decode(
            await avatarResponse.stream.bytesToString(),
          );
          final updatedUser = User(
            username: user.username,
            displayName: user.displayName,
            avatar: avatarData['avatar'],
            school: user.school,
          );
          await _saveUser(updatedUser);
          _navigateToHome(updatedUser);
          return;
        }
      }

      await _saveUser(user);
      _navigateToHome(user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('townsqr_user', json.encode(user.toJson()));
  }

  void _navigateToHome(User user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome to TownSqr',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Choose a Username',
                    hintText: 'username',
                    helperText: _usernameStatus,
                    helperStyle: TextStyle(
                      color: _isUsernameAvailable
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _checkUsername(value);
                    } else {
                      setState(() {
                        _usernameStatus = '';
                        _isUsernameAvailable = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSchool,
                  decoration: const InputDecoration(
                    labelText: 'Select Your School',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('wey school you dey...'),
                    ),
                    ...Constants.schools.map((school) {
                      return DropdownMenuItem(
                        value: school.value,
                        child: Text('${school.emoji} ${school.name}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSchool = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? const Text(
                              '?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _pickAvatar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Upload Photo'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Join TownSqr'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
