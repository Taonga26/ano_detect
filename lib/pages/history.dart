import 'dart:io';

import 'package:ano_detect/pages/pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<FileObject> files = [];

  @override
  void initState() {
    super.initState();
    loadFiles();
  }



  Future<void> _openFilePreview(String userPath, String fileName) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing preview for $fileName...')),
    );

    try {
      // Creating a signed URL that's valid for 60 seconds
      final signedUrl = await supabase.storage
          .from('reports')
          .createSignedUrl(userPath, 60);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FilePreviewPage(
              fileUrl: signedUrl,
              fileName: fileName,
            ),
          ),
        );
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    }
  }


  Future<void> loadFiles() async {
    final user = supabase.auth.currentUser;
    try {
      final response = await supabase.storage.from('reports').list(path: user!.id);

      setState(() {
        files = response;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error loading files: $e")));
    }
  }

  Future<void> deleteFile(String fileName) async {
    final user = supabase.auth.currentUser;
    final filePath = '${user!.id}/$fileName';

    try {
      await supabase.storage.from('reports').remove([filePath]);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Deleted: $fileName")));

      loadFiles(); 
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  Future<void> openPreview(String fileName) async {
    final publicUrl =
    supabase.storage.from('reports').getPublicUrl(fileName);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewPage(
          fileUrl: publicUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  Future<void> downloadFile(String fileName) async {
    try {
      final fileUrl =
      supabase.storage.from('reports').getPublicUrl(fileName);

      final dir = await getTemporaryDirectory();
      final savePath = "${dir.path}/$fileName";

      final response = await http.get(Uri.parse(fileUrl));

      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      await OpenFile.open(savePath);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("File opened: $fileName")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to open file: $e")));
    }
  }

  void confirmDelete(String fileName) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete File"),
          content: Text("Are you sure you want to delete $fileName?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () {
                Navigator.pop(context);
                deleteFile(fileName);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        backgroundColor: Colors.blueAccent,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
          ? const Center(child: Text("No files uploaded yet."))
          : ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          final item = files[index];
          return ListTile(
            style: ListTileStyle.list,
            tileColor: Colors.grey[200],
            leading: const Icon(Icons.insert_drive_file),
            title: Text(item.name),
            onTap: () async {
              final user = supabase.auth.currentUser;
              // Construct the full path required for the call
              final userPath = '${user!.id}/${item.name}';
              // Call the new preview function
              await _openFilePreview(userPath, item.name);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => confirmDelete(item.name),
            ),
          );
        },
      ),
    );
  }
}
