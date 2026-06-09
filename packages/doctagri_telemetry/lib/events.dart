enum TelemetryEvent {
  appStarted('app_started'),
  appReady('app_ready'),
  diagnosisStarted('diagnosis_started'),
  diagnosisCompleted('diagnosis_completed'),
  diagnosisLowConfidence('diagnosis_low_confidence'),
  expertValidationRequested('expert_validation_requested'),
  offlineSyncFailed('offline_sync_failed'),
  offlineSyncSuccess('offline_sync_success'),
  modelLoaded('model_loaded'),
  modelInference('model_inference'),
  userLoggedIn('user_logged_in'),
  userSignedUp('user_signed_up'),
  settingsChanged('settings_changed');

  final String eventName;
  const TelemetryEvent(this.eventName);
}

class EventProperties {
  final Map<String, dynamic> _props = {};

  EventProperties();

  EventProperties add(String key, dynamic value) {
    _props[key] = value;
    return this;
  }

  EventProperties modelVersion(String v) => add('model_version', v);
  EventProperties confidence(double v) => add('confidence', v);
  EventProperties cropId(String v) => add('crop_id', v);
  EventProperties latencyMs(int v) => add('latency_ms', v);
  EventProperties errorMessage(String v) => add('error_message', v);
  EventProperties region(String v) => add('region', v);
  EventProperties locale(String v) => add('locale', v);
  EventProperties appVersion(String v) => add('app_version', v);
  EventProperties platform(String v) => add('platform', v);

  Map<String, dynamic> toMap() => Map.unmodifiable(_props);
}
