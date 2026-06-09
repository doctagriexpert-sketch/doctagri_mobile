class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._();

  final Map<String, bool> _cache = {};
  DateTime? _lastFetch;

  static const _cacheDuration = Duration(minutes: 5);

  Future<bool> isEnabled(String key) async {
    if (_isCacheValid()) {
      return _cache[key] ?? false;
    }
    await _refresh();
    return _cache[key] ?? false;
  }

  bool _isCacheValid() {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheDuration;
  }

  Future<void> _refresh() async {
    // TODO: Fetch from Supabase feature_flags table
    // For now, use seed values
    _cache.addAll({
      'offline_mode': true,
      'voice_assistant': false,
      'expert_validation': true,
      'telemetry': true,
      'beta_models': false,
    });
    _lastFetch = DateTime.now();
  }

  Future<void> invalidateCache() async {
    _lastFetch = null;
    await _refresh();
  }
}
