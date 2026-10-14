import '../../services/feature_gateway.dart';

int? depositMinorUnits(String input) {
  final amount = parseMinorUnits(input);
  return amount != null && amount >= 10000 && amount <= 100000000
      ? amount
      : null;
}
