import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Allow empty input or if user is deleting all content
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get digits only
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newText.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // Prevent leading zeros unless it's the only digit
    if (newText.length > 1 && newText.startsWith('0')) {
      newText = newText.substring(1);
    }

    // Limit to a reasonable length to prevent overflow with formatting, e.g., 9 digits for hundreds of millions
    if (newText.length > 9) {
      newText = newText.substring(0, 9);
    }

    double value = double.tryParse(newText) ?? 0.0;
    String formattedText = _formatter.format(value);

    // Calculate cursor position
    // This is a simplified cursor handling. For more complex scenarios, it might need refinement.
    // Generally, we want the cursor at the end of the newly formatted text.
    int selectionOffset = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}

