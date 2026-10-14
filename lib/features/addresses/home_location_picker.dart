import 'package:flutter/material.dart';
import '../../models/misc_models.dart';

/// The existing address selector writes the booking pickup before returning.
Future<SavedAddress?> chooseHomeLocation(BuildContext context) async {
  final selected = await Navigator.pushNamed(context, '/select-address');
  if (selected == null) return null;
  if (selected is! SavedAddress) {
    throw StateError('An address selection was not returned.');
  }
  return selected;
}
