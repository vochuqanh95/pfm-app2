abstract class TwoFactorService {
  /// Request a 2FA code for the given user
  Future<void> requestCodeForUser(String userId);

  /// Verify the code entered by the user
  Future<bool> verifyCode(String userId, String code);
}

class MockTwoFactorService implements TwoFactorService {
  // In-memory storage for codes
  final Map<String, _CodeData> _codes = {};

  // Fixed code for testing
  static const String _fixedCode = '123456';

  // Code expiration time (5 minutes)
  static const Duration _codeExpiration = Duration(minutes: 5);

  @override
  Future<void> requestCodeForUser(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Store the code with timestamp
    _codes[userId] = _CodeData(
      code: _fixedCode,
      generatedAt: DateTime.now(),
    );

    // In a real implementation, this would send an email or SMS
    // For now, we just print to console for testing
    print('2FA Code for user $userId: $_fixedCode');
  }

  @override
  Future<bool> verifyCode(String userId, String code) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final codeData = _codes[userId];

    // Check if code exists
    if (codeData == null) {
      return false;
    }

    // Check if code is expired
    final now = DateTime.now();
    if (now.difference(codeData.generatedAt) > _codeExpiration) {
      _codes.remove(userId);
      return false;
    }

    // Verify the code matches
    final isValid = codeData.code == code;

    // Remove the code after verification (one-time use)
    if (isValid) {
      _codes.remove(userId);
    }

    return isValid;
  }
}

class _CodeData {
  final String code;
  final DateTime generatedAt;

  _CodeData({
    required this.code,
    required this.generatedAt,
  });
}
