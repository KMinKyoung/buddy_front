import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
            onPressed:  () => Navigator.pushNamed(context, AppRoutes.home),
            child: const Text('go home')),
      ),
    );
  }
}
