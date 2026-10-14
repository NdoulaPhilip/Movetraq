import '../../core/networking/api.dart';

class OrderRepository {
  const OrderRepository(this.api);
  final ApiClient api;
  String _id(String id) {
    if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id)) {
      throw ArgumentError('A valid order or quote ID is required.');
    }
    return id;
  }

  Map<String, dynamic> _record(Map<String, dynamic> result, String key) {
    final record = result[key];
    if (record is! Map) {
      throw const FormatException(
          'The server did not return the requested record.');
    }
    return Map<String, dynamic>.from(record);
  }

  Future<Map<String, dynamic>> quote(Map<String, dynamic> input) async =>
      _record(
          await api.request('/quotes', method: 'POST', data: input), 'quote');
  Future<Map<String, dynamic>> create(String quoteId, String key) async =>
      _record(
          await api.request('/orders',
              method: 'POST', data: {'quoteId': _id(quoteId)}, key: key),
          'order');
  Future<Map<String, dynamic>> detail(String id) async =>
      _record(await api.request('/orders/${_id(id)}'), 'order');
  Future<Map<String, dynamic>> command(String id, String command,
      {Map<String, dynamic> input = const {}}) async {
    if (input.containsKey('command') || input.containsKey('status')) {
      throw ArgumentError(
          'Order status must be controlled by the server command.');
    }
    if (!const [
      'request_payment',
      'fund',
      'accept',
      'heading_to_pickup',
      'arrived_pickup',
      'picked_up',
      'heading_to_dropoff',
      'arrived_dropoff',
      'confirm_receipt',
      'returning',
      'returned',
      'offer',
      'assign',
      'cancel',
      'reject',
      'report_issue',
      'handover'
    ].contains(command)) {
      throw ArgumentError('Unsupported order command.');
    }
    return _record(
        await api.request('/orders/${_id(id)}/commands',
            method: 'POST', data: {'command': command, ...input}),
        'order');
  }
}
