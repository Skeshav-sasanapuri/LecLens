import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:leclens/pages/chat_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LecLens',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(), // Beautiful font
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove default back button
        backgroundColor: Colors.black, // Dark color background
        centerTitle: true, // Center align title
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/logo.png',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 10),
            Text(
              "LecLens",
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text
                letterSpacing: 1.5,
              ),
            )
          ],
        ),
      ),
      body: const ChatPage(), 
    );
  }
}
