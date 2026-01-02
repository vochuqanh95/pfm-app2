import '../../data/models/user_model.dart';

/// Actor information for transaction attribution
class ActorInfo {
  final String userId;
  final String displayName;
  final String role; // "head" or "member"

  const ActorInfo({
    required this.userId,
    required this.displayName,
    required this.role,
  });
}

/// Build actor info from a UserModel
///
/// This helper ensures consistent actor attribution across all transactions.
/// Uses smart fallback logic to get the best available display name:
/// 1. User's name (if valid and not a placeholder)
/// 2. Formatted email local part (capitalize, handle dots)
/// 3. Full email address
/// 4. User ID (truncated)
/// 5. 'User' as last resort
ActorInfo buildActorInfo(UserModel user) {
  final role = user.isHead ? 'head' : 'member';
  final displayName = _getSmartDisplayName(user);

  return ActorInfo(
    userId: user.userId,
    displayName: displayName,
    role: role,
  );
}

/// Smart display name extraction with fallbacks
/// Uses the same logic as HouseholdMemberDetail.displayName
String _getSmartDisplayName(UserModel user) {
  final userName = (user.name).trim();

  // Check if name is valid and not a generic placeholder
  final isValidName = userName.isNotEmpty &&
      userName != 'Member' &&
      userName != 'Household Member' &&
      userName != 'Household Owner' &&
      userName != 'User';

  if (isValidName) {
    return userName;
  }

  // Try to extract name from email (before @)
  final email = (user.email).trim();
  if (email.isNotEmpty && email.contains('@')) {
    final localPart = email.split('@').first;

    // If email has dots (like first.last@email.com), format nicely
    if (localPart.contains('.')) {
      final parts = localPart.split('.');
      return parts
          .where((p) => p.isNotEmpty)
          .map((p) => p.substring(0, 1).toUpperCase() + p.substring(1))
          .join(' ');
    }

    // Capitalize first letter of simple email local part
    if (localPart.isNotEmpty && !localPart.contains('.')) {
      return localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
    }

    return localPart;
  }

  // Return full email if no @ found
  if (email.isNotEmpty) {
    return email;
  }

  // Fall back to short form of userId if both name and email are missing
  final userId = user.userId;
  if (userId.length > 8) {
    return '${userId.substring(0, 8)}...';
  }

  return userId.isNotEmpty ? userId : 'User';
}

/// Format actor label for display in transaction lists
/// Example: "Quốc Anh Võ Chu (head)" or "Nguyen Van A (member)"
String formatActorLabel(String? actorDisplayName, String? actorRole) {
  final name = (actorDisplayName ?? '').trim();
  final role = (actorRole ?? '').trim();

  final displayName = name.isNotEmpty ? name : 'Unknown';
  if (role.isEmpty) return displayName;

  final roleLabel = role == 'head' ? 'head' : 'member';
  return '$displayName ($roleLabel)';
}
