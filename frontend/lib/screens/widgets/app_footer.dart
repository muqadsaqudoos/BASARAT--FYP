import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onHelp;
  final Widget micButton;

  const AppFooter({
    super.key,
    required this.onHome,
    required this.onHelp,
    required this.micButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16), // 👈 slight bottom margin
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined, color: Colors.blue),
            ),
            micButton,
            IconButton(
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
