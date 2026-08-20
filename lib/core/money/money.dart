class CurrencyMetadata {
  final String code;
  final int minorUnits;

  const CurrencyMetadata(this.code, {this.minorUnits = 2});
}

const defaultCurrency = CurrencyMetadata('USD');
const defaultCurrencyCode = 'USD';

const supportedCurrencyCodes = <String>[
  'EUR',
  'GBP',
  'INR',
  'JPY',
  'USD',
  'CAD',
  'AUD',
  'CHF',
];

String currencySymbolForCode(String code) {
  switch (code) {
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'INR':
      return '₹';
    case 'JPY':
      return '¥';
    case 'CAD':
      return 'CA\$';
    case 'AUD':
      return 'A\$';
    case 'CHF':
      return 'CHF ';
    default:
      return '\$';
  }
}

int majorToMinor(double amount, {int minorUnits = 2}) {
  final text = amount.toStringAsFixed(minorUnits);
  final negative = text.startsWith('-');
  final digits = negative ? text.substring(1) : text;
  final parts = digits.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1
      ? 0
      : int.parse(parts[1].padRight(minorUnits, '0').substring(0, minorUnits));
  final value = whole * _pow10(minorUnits) + fraction;
  return negative ? -value : value;
}

String minorToMajorString(int amountMinor, {int minorUnits = 2}) {
  final negative = amountMinor < 0;
  final absolute = amountMinor.abs();
  final scale = _pow10(minorUnits);
  final whole = absolute ~/ scale;
  final fraction = (absolute % scale).toString().padLeft(minorUnits, '0');
  return '${negative ? '-' : ''}$whole.${fraction.isEmpty ? '0' : fraction}';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
