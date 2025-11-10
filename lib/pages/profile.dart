import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      // AuthListener in main.dart will redirect to LoginPage
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('user_profiles')
              .stream(primaryKey: ['id'])
              .eq('user_id', user.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = (snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!.first
                : null;

            final fullName = profile?['full_name'] ?? '';
            final avatarUrl = profile?['avatar_url'];

            return Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                      fullName.isNotEmpty
                          ? fullName[0].toUpperCase()
                          : user.email![0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    fullName.isNotEmpty ? fullName : user.email!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
