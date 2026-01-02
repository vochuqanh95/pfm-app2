# Category Permission & Stale Stream Fixes - Summary

## Problem Statement
The app was crashing/losing connection right after launch with multiple Firestore `PERMISSION_DENIED` errors on the `categories` collection, often showing queries for different user_ids after logout/login.

## Root Causes Identified

1. **Firestore Rules Missing Legacy Field Support**: Category rules only checked `user_id` and `household_id` (snake_case), but old documents may have used `userId` and `householdId` (camelCase), causing permission denials.

2. **No Error Handling**: Category stream queries had no `.handleError()`, so permission-denied errors would crash the app instead of gracefully returning empty lists.

3. **Stale Streams After Logout/Login**: Category StreamProviders were not invalidated when auth changed, causing old user streams to continue querying with stale user_ids.

4. **No Auth Mismatch Guard**: No defensive check to prevent category providers from using params with old user_ids during auth transitions.

## Fixes Implemented

### 1. Updated Firestore Rules (`firestore.rules`)
**Location**: Lines 657-738

**Changes**:
- Added `categoryUserId()` helper with camelCase fallback:
  ```javascript
  function categoryUserId() {
    return resource.data.user_id != null
      ? resource.data.user_id
      : resource.data.userId;
  }
  ```
- Added `categoryHouseholdId()` helper with camelCase fallback:
  ```javascript
  function categoryHouseholdId() {
    return resource.data.household_id != null
      ? resource.data.household_id
      : resource.data.householdId;
  }
  ```
- Added `isArchived()` helper for archived field support
- Updated all `allow get, list` rules to use these helpers
- Maintains backward compatibility with old documents

**Result**: Rules now work with both new (snake_case) and legacy (camelCase) category documents.

### 2. Added Error Handling to Repository (`category_repository.dart`)
**Location**: Lines 144-201

**Changes**:
- Added defensive guard: if `userId.isEmpty`, return empty stream immediately
- Added `.handleError()` to personal stream:
  ```dart
  .handleError((error) {
    debugPrint('[CATEGORY_REPO] Personal stream error (type=${type.name}, user=$userId): $error');
    return <CategoryModel>[];
  })
  ```
- Added `.handleError()` to household stream (same pattern)
- Errors (like permission-denied) now return empty list instead of crashing

**Result**: App gracefully handles permission errors without crashing.

### 3. Added Auth Invalidation Gate (`category_provider.dart`)
**Location**: Lines 29-39

**Changes**:
- Created `_categoryAuthGateProvider` that watches `authStateProvider`
- Provider returns current auth user ID
- Logs auth changes: `[CATEGORY_AUTH_GATE] Current auth user: <userId>`

**Result**: When auth changes (logout/login), all category providers that watch this gate will auto-invalidate.

### 4. Updated Category Stream Provider (`category_provider.dart`)
**Location**: Lines 89-115

**Changes**:
- Added `ref.watch(_categoryAuthGateProvider)` to trigger invalidation on auth changes
- Added defensive auth mismatch check:
  ```dart
  if (currentAuthUserId != null && params.userId != currentAuthUserId) {
    debugPrint('[CATEGORY_PROVIDER] Auth mismatch: params.userId=${params.userId} != currentAuth=$currentAuthUserId, returning empty');
    return Stream.value(<CategoryModel>[]);
  }
  ```
- Enhanced disposal logging

**Result**: Prevents stale streams from querying with old user_ids during auth transitions.

### 5. Updated Other Category Providers
**Location**: Lines 117-130, 154-161

**Changes**:
- `categoryByIdProvider`: Added `ref.watch(_categoryAuthGateProvider)`
- `categoryNameMapProvider`: Added `ref.watch(_categoryAuthGateProvider)`

**Result**: All category providers now refresh on auth changes.

## Testing Instructions

### Crash Capture (Windows)
Run in a separate terminal to capture crash logs:
```cmd
adb logcat -v time | findstr /i "FATAL EXCEPTION E/flutter FirebaseFirestore permission-denied I/flutter"
```

### Manual Test Checklist

**T1: Launch with Head user**
- ✅ Open Add Transaction → categories load (no permission denied)
- ✅ Check logcat: `[CATEGORY_REPO] Stream categories` appears
- ✅ Check logcat: No PERMISSION_DENIED errors

**T2: Logout → Login as Member**
- ✅ Immediately open Add Transaction → categories load without "Reload" button
- ✅ Check logcat: `[CATEGORY_AUTH_GATE] Current auth user:` shows new userId
- ✅ Check logcat: `[CATEGORY_PROVIDER] Disposed stream` for old user
- ✅ CRITICAL: Logcat must NOT show queries for previous user_id

**T3: Repeat logout/login 3 times**
- ✅ No growing number of category listeners
- ✅ Check logcat for `[CATEGORY_PROVIDER] Disposed` messages (should appear each time)
- ✅ No memory leaks (streams are properly cleaned up)

**T4: Create personal expense category**
- ✅ Saved successfully (no permission denied)
- ✅ Appears immediately in picker list (no need to reopen screen)
- ✅ Check logcat: `[CATEGORY_REPO] Creating custom category`

**T5: Household custom category**
- ✅ Head can create (succeeds)
- ✅ Member can read (appears in their picker)
- ✅ Member cannot create/edit/delete household category (permission denied shown gracefully)

**T6: Verify no crash**
- ✅ App stays running after launching
- ✅ No "Lost connection to device" in Flutter output
- ✅ If crash occurs: Check captured FATAL EXCEPTION stacktrace

## Key Log Messages to Monitor

**Success indicators**:
```
[CATEGORY_AUTH_GATE] Current auth user: <userId>
[CATEGORY_REPO] Stream categories type=expense user=<userId> household=<householdId>
[CATEGORY_REPO] Emitting categories (...): builtIn=6, personal=0, household=1
[CATEGORY_PROVIDER] Created stream for type=expense user=<userId>
```

**Error handling (expected, non-critical)**:
```
[CATEGORY_REPO] Personal stream error (...): permission-denied
[CATEGORY_PROVIDER] Auth mismatch: params.userId=<oldId> != currentAuth=<newId>, returning empty
```

**Red flags (investigate if seen)**:
```
PERMISSION_DENIED (should not appear if rules are correct)
FATAL EXCEPTION (should not happen with error handling)
```

## Files Modified

1. `firestore.rules` (lines 657-738)
   - Added camelCase fallback support for category fields

2. `lib/data/repositories/category_repository.dart` (lines 144-201)
   - Added userId guard
   - Added error handling to streams

3. `lib/presentation/providers/category_provider.dart` (lines 1-161)
   - Added manual test checklist comments (lines 1-17)
   - Added auth gate provider (lines 29-39)
   - Updated all category providers to watch auth gate
   - Added auth mismatch defensive check

## Deployment Steps Completed

1. ✅ Updated Firestore rules
2. ✅ Deployed rules: `firebase deploy --only firestore:rules`
3. ✅ Updated repository code
4. ✅ Updated provider code
5. ✅ Rebuilt app: `flutter build apk --debug`
6. ✅ Installed app: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`

## Next Steps

1. **Test the app** following the checklist above
2. **Monitor logs** for the success indicators
3. **Report results**:
   - If T1-T6 all pass: Categories module is fixed ✅
   - If any test fails: Provide the specific logcat output and describe what failed

## Backward Compatibility

- ✅ Old documents with `userId`/`householdId` (camelCase) still work
- ✅ New documents use `user_id`/`household_id` (snake_case)
- ✅ No schema migration required
- ✅ Firestore rules handle both formats transparently

## Safe Scope Verification

Changes were limited to:
- ✅ Category module only (repository, providers, Firestore rules)
- ✅ No changes to Wallet/Transactions/Budgets/Debts logic
- ✅ No breaking schema changes
- ✅ Auth lifecycle handling (category-specific invalidation)

---

**Status**: Ready for testing
**Date**: 2025-12-20
**Version**: 1.0.0+1
