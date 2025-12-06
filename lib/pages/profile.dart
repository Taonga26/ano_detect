import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  bool _isEditing = false;
  bool _isLoading = false;

  // Controllers for the text fields
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      // AuthListener in main.dart will redirect to LoginPage
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
    }
  }

  // --- Function to update the user profile ---
  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final updates = {
      'id': user.id,
      'full_name': _fullNameController.text.trim(),
      'username': _usernameController.text.trim(),
    };

    try {
      // Use upsert to update the profile
      await supabase.from('user_profiles').upsert(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blueAccent,
        // --- EDIT/SAVE BUTTON ---
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                // If currently editing, trigger the update
                _updateProfile();
              } else {
                // If not editing, switch to editing mode
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('user_profiles').stream(primaryKey: ['id']).eq('id', user.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error fetching profile: ${snapshot.error}"));
            }

            final profile = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data!.first : null;

            // --- Set controller text ONLY if not currently editing ---
            if (!_isEditing) {
              _fullNameController.text = profile?['full_name'] as String? ?? '';
              _usernameController.text = profile?['username'] as String? ?? '';
            }

            final avatarUrl = profile?['avatar_url'] as String?;

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: ListView( // Use ListView to prevent overflow
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                        _fullNameController.text.isNotEmpty
                            ? _fullNameController.text[0].toUpperCase()
                            : user.email![0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white),
                      )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // --- EDITABLE FULL NAME ---
                    TextFormField(
                      controller: _fullNameController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // --- EDITABLE USERNAME ---
                    TextFormField(
                      controller: _usernameController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),

                    // --- NON-EDITABLE EMAIL ---
                    TextFormField(
                      initialValue: user.email!,
                      enabled: false, // Email is not editable
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 40),

                    // --- LOGOUT BUTTON ---
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
