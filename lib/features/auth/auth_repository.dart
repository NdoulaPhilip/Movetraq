export 'repositories/production_auth_repository.dart';
import 'repositories/production_auth_repository.dart';

/// Production auth remains server-mediated; profiles cannot grant themselves roles.
typedef AuthRepository = ProductionAuthRepository;
