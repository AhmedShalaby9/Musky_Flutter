// Parse EGP into piastres using integer arithmetic, never binary floating point.
int? parseMoney(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  final parts = text.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 10000000000) {
    return null;
  }
  final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final minor = whole * 100 + cents;
  return minor <= 1000000000000 ? minor : null;
}

String moneyInput(int minor) =>
    '${minor ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';
String egp(int minor) {
  final amount = minor.abs();
  final whole = (amount ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '${minor < 0 ? '-' : ''}EGP $whole.${(amount % 100).toString().padLeft(2, '0')}';
}

String invoiceLabel(Map<String, dynamic> invoice) => invoice['number'] == null
    ? 'Draft #${invoice['id']}'
    : 'INV-${invoice['number'].toString().padLeft(6, '0')}';
