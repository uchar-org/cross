import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

class CheckRoot extends StatefulWidget {
  const CheckRoot({super.key});


  @override
  State<CheckRoot> createState() => _CheckRootState();
}

class _CheckRootState extends State<CheckRoot> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        body: Container(
          color: Colors.black,
          child: Center(
            child: Text(
              "${L10n.of(context).yourPhoneIsRooted} 🔒",
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
