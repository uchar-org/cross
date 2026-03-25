import 'package:flutter/material.dart';

class CheckRoot extends StatefulWidget {
  const CheckRoot({super.key, required this.text});

  final String text;

  @override
  State<CheckRoot> createState() => _CheckRootState();
}

class _CheckRootState extends State<CheckRoot> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          "Your phone is rooted 🔒",
          textDirection: TextDirection.ltr,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
