/// Stub implementation for non-web platforms (Android/iOS).
/// These functions are no-ops outside the browser environment.

String? getShareParamFromUrl() => null;
void cleanShareParamFromUrl() {}
bool webCanShare() => false;
void listenWebLaunchQueue(void Function(String shareId) onShare) {}
