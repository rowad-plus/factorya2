import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

/// Renders the small subset of HTML the "about us" rich-text editor produces
/// (`<b> <i> <u> <s> <ul> <ol> <li> <a> <p> <br> <div>`) without the `flutter_html`
/// package, whose web build is broken on this Flutter version. Anything else is
/// shown as plain text.
class SimpleHtml extends StatelessWidget {
  final String data;
  final TextStyle style;
  final Color linkColor;
  const SimpleHtml({super.key, required this.data, required this.style, required this.linkColor});

  @override
  Widget build(BuildContext context) {
    final doc = html_parser.parse(data);
    final blocks = _blocks(doc.body ?? doc.documentElement!, style);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks.isEmpty ? [Text(data, style: style)] : blocks);
  }

  List<Widget> _blocks(dom.Node root, TextStyle base) {
    final out = <Widget>[];
    final spans = <InlineSpan>[];

    void flush() {
      if (spans.isNotEmpty) {
        out.add(Text.rich(TextSpan(children: List.of(spans)), style: base));
        spans.clear();
      }
    }

    void walkInline(dom.Node node, TextStyle style) {
      if (node is dom.Text) {
        final t = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (t.trim().isNotEmpty || spans.isNotEmpty) spans.add(TextSpan(text: t, style: style));
        return;
      }
      if (node is! dom.Element) return;
      switch (node.localName) {
        case 'b':
        case 'strong':
          for (final c in node.nodes) {
            walkInline(c, style.copyWith(fontWeight: FontWeight.w800));
          }
        case 'i':
        case 'em':
          for (final c in node.nodes) {
            walkInline(c, style.copyWith(fontStyle: FontStyle.italic));
          }
        case 'u':
          for (final c in node.nodes) {
            walkInline(c, style.copyWith(decoration: TextDecoration.underline));
          }
        case 's':
        case 'strike':
        case 'del':
          for (final c in node.nodes) {
            walkInline(c, style.copyWith(decoration: TextDecoration.lineThrough));
          }
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        case 'a':
          final href = node.attributes['href'];
          spans.add(TextSpan(
            text: node.text,
            style: style.copyWith(color: linkColor, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (href == null || href.isEmpty) return;
                final uri = Uri.tryParse(href);
                if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
          ));
        default:
          for (final c in node.nodes) {
            walkInline(c, style);
          }
      }
    }

    for (final node in root.nodes) {
      if (node is dom.Text) {
        if (node.text.trim().isEmpty) continue;
        walkInline(node, base);
        continue;
      }
      if (node is! dom.Element) continue;
      switch (node.localName) {
        case 'ul':
        case 'ol':
          flush();
          final ordered = node.localName == 'ol';
          var i = 1;
          for (final li in node.children.where((e) => e.localName == 'li')) {
            final marker = ordered ? '${i++}.' : '•';
            out.add(Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 18, child: Text(marker, style: base)),
                Expanded(child: Text.rich(TextSpan(children: _inlineSpans(li, base)), style: base)),
              ]),
            ));
          }
        case 'p':
        case 'div':
          flush();
          final inner = _blocks(node, base);
          if (inner.isNotEmpty) {
            out.addAll(inner);
            out.add(const SizedBox(height: 6));
          }
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        default:
          walkInline(node, base);
      }
    }
    flush();
    return out;
  }

  List<InlineSpan> _inlineSpans(dom.Element el, TextStyle base) {
    final spans = <InlineSpan>[];
    void walk(dom.Node node, TextStyle style) {
      if (node is dom.Text) {
        spans.add(TextSpan(text: node.text.replaceAll(RegExp(r'\s+'), ' '), style: style));
        return;
      }
      if (node is! dom.Element) return;
      switch (node.localName) {
        case 'b':
        case 'strong':
          for (final c in node.nodes) {
            walk(c, style.copyWith(fontWeight: FontWeight.w800));
          }
        case 'i':
        case 'em':
          for (final c in node.nodes) {
            walk(c, style.copyWith(fontStyle: FontStyle.italic));
          }
        case 'u':
          for (final c in node.nodes) {
            walk(c, style.copyWith(decoration: TextDecoration.underline));
          }
        default:
          for (final c in node.nodes) {
            walk(c, style);
          }
      }
    }
    for (final c in el.nodes) {
      walk(c, base);
    }
    return spans;
  }
}
