import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/companies/data/models/organization.dart';
import '../../features/companies/data/organization_repository.dart';

class TypographyController extends StateNotifier<CompanyTypographySettings> {
  TypographyController(this._ref) : super(const CompanyTypographySettings());

  final Ref _ref;
  Future<CompanyTypographySettings>? _loadFuture;

  Future<CompanyTypographySettings> ensureLoaded({bool force = false}) {
    if (!force && _loadFuture == null && _hasLoadedOnce) {
      return Future.value(state);
    }
    if (_loadFuture != null && !force) {
      return _loadFuture!;
    }
    _loadFuture = _load().whenComplete(() {
      _loadFuture = null;
    });
    return _loadFuture!;
  }

  bool _hasLoadedOnce = false;

  Future<CompanyTypographySettings> _load() async {
    try {
      final settings = await _ref.read(organizationRepositoryProvider).getCompanyTypography();
      state = settings;
    } catch (_) {
      state = const CompanyTypographySettings();
    }
    _hasLoadedOnce = true;
    return state;
  }
}

final typographyControllerProvider =
    StateNotifierProvider<TypographyController, CompanyTypographySettings>((ref) {
  return TypographyController(ref);
});
