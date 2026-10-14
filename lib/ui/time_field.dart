import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/clock_time.dart';
import 'theme.dart';

/// Klavyeyle hızlı saat girişi: "0840", "840", "08.40" ve "08:40" aynı
/// saattir. Geçersiz girişte çerçeve kırmızı olur ve değer bildirilmez.
class TimeField extends StatefulWidget {
  const TimeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.width = 96,
  });

  final ClockTime? value;
  final ValueChanged<ClockTime> onChanged;
  final String semanticLabel;
  final double width;

  /// Girilen metni saate çevirir; anlaşılmazsa null.
  static ClockTime? parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      if (t.contains(':') || t.contains('.')) return ClockTime.parse(t);
      if (t.length == 3 || t.length == 4) {
        return ClockTime.tryCreate(int.parse(t.substring(0, t.length - 2)), int.parse(t.substring(t.length - 2)));
      }
      if (t.length <= 2) return ClockTime.tryCreate(int.parse(t), 0);
    } catch (_) {}
    return null;
  }

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  late final _controller = TextEditingController(text: widget.value?.toString() ?? '');
  final _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Alandan çıkınca geçerli değeri düzgün biçimde yaz (0840 → 08:40).
      if (!_focus.hasFocus && mounted) {
        final parsed = TimeField.parse(_controller.text);
        if (parsed != null) _controller.text = parsed.toString();
        setState(() => _invalid = parsed == null);
      }
    });
  }

  @override
  void didUpdateWidget(TimeField old) {
    super.didUpdateWidget(old);
    // Değer dışarıdan değiştiyse (hızlı doldur, ders silme) metni güncelle.
    if (!_focus.hasFocus && TimeField.parse(_controller.text) != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final parsed = TimeField.parse(text);
    // Yazarken yarım girişi ("08:") hata sayma; 4+ karakterde değerlendir.
    setState(() => _invalid = parsed == null && text.length >= 4);
    if (parsed != null && parsed != widget.value) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _invalid ? AppColors.danger : AppColors.lineStrong, width: _invalid ? 2 : 1),
    );
    return SizedBox(
      width: widget.width,
      child: Semantics(
        label: widget.semanticLabel,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _changed,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
            LengthLimitingTextInputFormatter(5),
          ],
          style: const TextStyle(fontSize: 15, fontFeatures: tabularFigures),
          decoration: InputDecoration(
            hintText: 'ss:dd',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: _invalid ? AppColors.danger : AppColors.lesson, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
