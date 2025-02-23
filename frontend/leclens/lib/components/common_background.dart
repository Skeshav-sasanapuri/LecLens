import 'package:flutter/material.dart';

class CommonBackground extends StatelessWidget {
  final Widget child;

  const CommonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.25, 0.75, 1.0],
            colors: [
              Color.fromARGB(255, 43, 43, 43),
              Color.fromARGB(199, 150, 150, 150),
              Color.fromARGB(255, 255, 210, 195),
              Color.fromARGB(255, 239, 239, 239),
            ],
          ),
        ),
        child: SafeArea(
          child: child,
        ),
      ),
    );
  }
}