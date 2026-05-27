import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A date input that:
/// - accepts typed digits and auto-inserts slashes (jj/mm/aaaa)
/// - has a calendar button to fall back to the native picker
/// - reports a valid [DateTime] (or null while incomplete/invalid)
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.hint = 'jj/mm/aaaa',
    this.helperText,
    this.required = false,
  });

  final String label;
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String hint;
  final String? helperText;
  final bool required;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.initialDate));
  }

  @override
  void didUpdateWidget(DateField old) {
    super.didUpdateWidget(old);
    if (old.initialDate != widget.initialDate) {
      final formatted = _format(widget.initialDate);
      if (_ctrl.text != formatted) _ctrl.text = formatted;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _format(DateTime? d) =>
      d == null ? '' :
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parse(String text) {
    if (text.length != 10) return null;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    if (y < 1900 || y > 2100) return null;
    final date = DateTime(y, m, d);
    if (date.day != d || date.month != m || date.year != y) return null; // catches 31/02 etc.
    return date;
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      setState(() => _error = widget.required ? 'Date requise' : null);
      widget.onChanged(null);
      return;
    }
    if (text.length < 10) {
      // incomplete — clear error until they're done
      setState(() => _error = null);
      widget.onChanged(null);
      return;
    }
    final parsed = _parse(text);
    if (parsed == null) {
      setState(() => _error = 'Date invalide');
      widget.onChanged(null);
      return;
    }
    if (widget.firstDate != null && parsed.isBefore(widget.firstDate!)) {
      setState(() => _error = 'Trop ancien');
      widget.onChanged(null);
      return;
    }
    if (widget.lastDate != null && parsed.isAfter(widget.lastDate!)) {
      setState(() => _error = 'Date future non autorisée');
      widget.onChanged(null);
      return;
    }
    setState(() => _error = null);
    widget.onChanged(parsed);
  }

  Future<void> _openPicker() async {
    final initial = _parse(_ctrl.text) ?? widget.initialDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime.now().add(const Duration(days: 365)),
      cancelText: 'Annuler',
      confirmText: 'OK',
      helpText: widget.label,
    );
    if (picked != null) {
      _ctrl.text = _format(picked);
      setState(() => _error = null);
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [_DateMaskFormatter()],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: _error,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today, size: 18),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ctrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  setState(() => _error = widget.required ? 'Date requise' : null);
                  widget.onChanged(null);
                },
              ),
            IconButton(
              icon: const Icon(Icons.date_range, size: 20),
              tooltip: 'Calendrier',
              onPressed: _openPicker,
            ),
          ],
        ),
      ),
      onChanged: _onTextChanged,
      validator: widget.required
          ? (v) {
              if (v == null || v.isEmpty) return 'Date requise';
              if (_parse(v) == null) return 'Date invalide';
              return null;
            }
          : (v) {
              if (v == null || v.isEmpty) return null;
              if (_parse(v) == null) return 'Date invalide';
              return null;
            },
    );
  }
}

/// Auto-inserts `/` after positions 2 and 4 — e.g. typing `230526` → `23/05/26`.
class _DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) {
    final digits = v.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(limited[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
