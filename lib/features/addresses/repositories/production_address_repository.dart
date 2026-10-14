import '../../auth/repositories/production_auth_repository.dart';
import '../models/production_address.dart';

class ProductionAddressRepository {
  const ProductionAddressRepository(this.auth);
  final ProductionAuthRepository auth;
  static const _path = '/users/me/addresses';
  String _endpoint(String id) {
    if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id)) {
      throw ArgumentError('A valid address ID is required.');
    }
    return '$_path/$id';
  }

  ProductionAddress _address(Map<String, dynamic> response) =>
      ProductionAddress.fromJson(
          Map<String, dynamic>.from(response['address'] as Map));
  Future<List<ProductionAddress>> list() async {
    final response = await auth.authenticatedRequest('GET', _path);
    return List<ProductionAddress>.unmodifiable((response['addresses'] as List)
        .map((row) =>
            ProductionAddress.fromJson(Map<String, dynamic>.from(row as Map))));
  }

  Future<ProductionAddress> add(AddressInput input) async => _address(
      await auth.authenticatedRequest('POST', _path, body: input.toJson()));
  Future<ProductionAddress> edit(String id, AddressInput input) async =>
      _address(await auth.authenticatedRequest('PUT', _endpoint(id),
          body: input.toJson()));
  Future<void> delete(String id) async {
    await auth.authenticatedRequest('DELETE', _endpoint(id));
  }

  Future<ProductionAddress> markDefault(String id) async => _address(
      await auth.authenticatedRequest('POST', '${_endpoint(id)}/default'));
  Future<void> select(String id) async {
    final response =
        await auth.authenticatedRequest('POST', '${_endpoint(id)}/select');
    if (response['selected_address_id'] != id) {
      throw const FormatException(
          'The server did not confirm address selection.');
    }
  }
}
