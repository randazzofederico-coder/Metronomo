/// Cached permission state from the last successful Firestore verification.
class PermissionCache {
  final bool hasAccess;
  final bool hasProfile;
  final String rol;
  final bool trialActive;
  final int trialDaysLeft;
  final bool trialExpired;
  final bool trialUsed;
  final DateTime lastVerified;

  const PermissionCache({
    required this.hasAccess,
    required this.hasProfile,
    required this.rol,
    required this.trialActive,
    required this.trialDaysLeft,
    required this.trialExpired,
    required this.trialUsed,
    required this.lastVerified,
  });

  int get daysSinceVerification =>
      DateTime.now().difference(lastVerified).inDays;

  int get daysUntilExpiry => (30 - daysSinceVerification).clamp(0, 30);

  bool get isExpired => daysSinceVerification >= 30;

  bool get showWarningBanner => daysUntilExpiry <= 5 && daysUntilExpiry > 0;
}
