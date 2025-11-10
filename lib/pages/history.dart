import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Reports')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('pdf_reports')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id) // only current user's PDFs
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('No reports found'));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(report['file_name']),
                subtitle: Text(report['created_at'] ?? ''),
                onTap: () async {
                  final url = report['url'];
                  if (url != null && url.isNotEmpty) {
                    // Open PDF using default viewer
                    await OpenFile.open(url);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
