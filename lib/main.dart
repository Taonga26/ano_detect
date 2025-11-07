import 'package:ano_detect/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const SUPABASE_URL = 'https://twzsjzeahkhidnwkchih.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3enNqemVhaGtoaWRud2tjaGloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0Mzg1NTEsImV4cCI6MjA3ODAxNDU1MX0.0rKT3VrruA0s4Hh7HSO_xak40x5NqXF3mHeh6-FiodY';


void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
