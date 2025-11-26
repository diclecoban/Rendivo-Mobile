import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart'; // primaryPink için, yolunu projene göre ayarla

Widget buildOwnerTextField({
  required TextEditingController controller,
  required String hintText,
  TextInputType? keyboardType,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(
          color: primaryPink,
          width: 1.4,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
