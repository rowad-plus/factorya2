import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// A small HTML source editor: a plain multi-line field plus a formatting toolbar
/// (bold, italic, underline, strike-through, bullet / numbered list, link) that wraps the
/// current selection in the matching tag. The site's "about us" field stores and renders
/// this same HTML (`dangerouslySetInnerHTML`), so what is written here shows formatted there.
class RichTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;

  const RichTextField({super.key, required this.controller, required this.label, this.helperText});

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  final _focus = FocusNode();

  void _wrap(String open, String close) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    if (!sel.isValid || sel.isCollapsed) {
      // Nothing selected: insert an empty tag pair with the cursor placed between them.
      final pos = sel.isValid ? sel.start : text.length;
      final newText = text.replaceRange(pos, pos, '$open$close');
      c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: pos + open.length));
    } else {
      final start = sel.start, end = sel.end;
      final selected = text.substring(start, end);
      final newText = text.replaceRange(start, end, '$open$selected$close');
      c.value = TextEditingValue(text: newText, selection: TextSelection(baseOffset: start, extentOffset: start + open.length + selected.length + close.length));
    }
    _focus.requestFocus();
  }

  void _prefixLines(String prefix) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    // Wrap each selected line (or the current line, if nothing is selected) as a <li>.
    final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;
    final block = text.substring(lineStart, lineEnd);
    final items = block.split('\n').where((l) => l.trim().isNotEmpty).map((l) => '<li>${l.trim()}</li>').join();
    final wrapped = '<$prefix>$items</$prefix>';
    final newText = text.replaceRange(lineStart, lineEnd, wrapped);
    c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: lineStart + wrapped.length));
    _focus.requestFocus();
  }

  void _insertLink() {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    final label = sel.isValid && !sel.isCollapsed ? text.substring(sel.start, sel.end) : '';
    showDialog<String>(
      context: context,
      builder: (dCtx) {
        final urlCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('رابط', textDirection: TextDirection.rtl),
          content: TextField(controller: urlCtrl, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'https://')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                final url = urlCtrl.text.trim();
                Navigator.pop(dCtx);
                if (url.isEmpty) return;
                final tag = '<a href="$url" target="_blank">${label.isEmpty ? url : label}</a>';
                if (sel.isValid && !sel.isCollapsed) {
                  final newText = text.replaceRange(sel.start, sel.end, tag);
                  c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: sel.start + tag.length));
                } else {
                  final pos = sel.isValid ? sel.start : text.length;
                  final newText = text.replaceRange(pos, pos, tag);
                  c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: pos + tag.length));
                }
              },
              child: const Text('إدراج'),
            ),
          ],
        );
      },
    );
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 18, color: const Color(0xFF4A5568))),
        ),
      );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Align(alignment: AlignmentDirectional.centerStart, child: Text(widget.label, style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: Colors.white),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFFF7F8FA), border: Border(bottom: BorderSide(color: AppColors.border))),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _btn(Icons.format_bold, 'عريض', () => _wrap('<b>', '</b>')),
                _btn(Icons.format_italic, 'مائل', () => _wrap('<i>', '</i>')),
                _btn(Icons.format_underline, 'تسطير', () => _wrap('<u>', '</u>')),
                _btn(Icons.strikethrough_s, 'يتوسطه خط', () => _wrap('<s>', '</s>')),
                Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppColors.border),
                _btn(Icons.format_list_bulleted, 'قائمة نقطية', () => _prefixLines('ul')),
                _btn(Icons.format_list_numbered, 'قائمة مرقّمة', () => _prefixLines('ol')),
                Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppColors.border),
                _btn(Icons.link, 'رابط', _insertLink),
              ]),
            ),
          ),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            minLines: 8,
            maxLines: 16,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.tajawal(fontSize: 13.5, height: 1.6),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              hintText: 'اكتب هنا...',
              hintStyle: GoogleFonts.tajawal(color: AppColors.muted),
            ),
          ),
        ]),
      ),
      if (widget.helperText != null) ...[
        const SizedBox(height: 6),
        Text(widget.helperText!, style: GoogleFonts.tajawal(fontSize: 11.5, color: AppColors.muted)),
      ],
    ]);
  }
}
