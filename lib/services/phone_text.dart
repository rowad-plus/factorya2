/// Phone numbers inside RTL (Arabic) text get reordered by the text engine
/// when they contain spaces, dashes or a leading "+" ("+20 106 600 3570"
/// shows as "3570 600 106 20+"). Wrapping each number in Unicode isolates
/// (LRI … PDI) keeps it left-to-right without changing the surrounding
/// layout. Same rule as the website's app/utils/phone.ts.
final String _lri = String.fromCharCode(0x2066);
final String _pdi = String.fromCharCode(0x2069);
final RegExp _phoneLike = RegExp(r'(?:\+|00)?\(?\d[\d\s().\-]{5,}\d');

String ltrPhones(String? text) {
  if (text == null || text.isEmpty) return text ?? '';
  return text.replaceAllMapped(_phoneLike, (m) => '$_lri${m[0]}$_pdi');
}
