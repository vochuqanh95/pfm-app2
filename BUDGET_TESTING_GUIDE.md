# Budget Feature Testing Guide

## Overview

This guide explains how to test the Budgets module to ensure it correctly tracks member spending against budget limits set by the household head.

## Prerequisites

- ✅ Cloud Functions deployed (see [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md))
- ✅ Flutter app running on device/emulator
- ✅ Test household with at least 2 members (head + 1 member)
- ✅ At least one household_shared wallet with balance

## Test Scenarios

### Scenario 1: Family Budget Tracking

**Goal:** Verify that family budgets track spending from ALL household members.

#### Setup
1. Log in as **Household Head**
2. Navigate to **Budgets** → **Add Budget**
3. Create a Family Budget:
   - Type: Family
   - Category: Food & Dining (or any category)
   - Amount: $1000
   - Period: Current month
   - Save

#### Test Steps
1. **Member A creates transaction:**
   - Log in as Member A
   - Create expense: $200 from household_shared wallet
   - Category: Food & Dining
   - Save

2. **Verify budget updates:**
   - Log in as Head
   - Go to Budgets
   - Family budget should show:
     - Spent: $200
     - Remaining: $800
     - Progress: 20%

3. **Member B creates transaction:**
   - Log in as Member B (or Head)
   - Create expense: $300 from household_shared wallet
   - Category: Food & Dining
   - Save

4. **Verify cumulative spending:**
   - Family budget should show:
     - Spent: $500 (200 + 300)
     - Remaining: $500
     - Progress: 50%

✅ **Expected:** Family budgets accumulate spending from all members

---

### Scenario 2: Member Budget Tracking

**Goal:** Verify that member budgets only track that specific member's spending.

#### Setup
1. Log in as **Household Head**
2. Navigate to **Budgets** → **Add Budget**
3. Create a Member Budget:
   - Type: Member
   - Assign to: Member A (select from dropdown)
   - Category: Shopping (or any category)
   - Amount: $500
   - Period: Current month
   - Save

#### Test Steps
1. **Member A creates transaction:**
   - Log in as Member A
   - Create expense: $150 from household_shared wallet
   - Category: Shopping
   - Save

2. **Verify budget updates:**
   - Member budget should show:
     - Spent: $150
     - Remaining: $350
     - Progress: 30%

3. **Member B creates transaction:**
   - Log in as Member B
   - Create expense: $200 from household_shared wallet
   - Category: Shopping
   - Save

4. **Verify Member A's budget unchanged:**
   - Member A's budget should still show:
     - Spent: $150 (unchanged)
     - Remaining: $350
     - Progress: 30%

5. **Verify Member B sees no budget:**
   - Log in as Member B
   - Go to Budgets
   - Member A's budget should NOT be visible
   - (Members can only see family budgets and their own member budgets)

✅ **Expected:** Member budgets only track that specific member's spending

---

### Scenario 3: Wallet Scope Filtering

**Goal:** Verify that only expenses from household_shared wallets affect budgets.

#### Setup
1. Create a member_private wallet for Member A
2. Create a family budget: $1000 for Transportation

#### Test Steps
1. **Transaction from household_shared wallet:**
   - Log in as Member A
   - Create expense: $50 from household_shared wallet
   - Category: Transportation
   - Save
   - **Verify:** Budget updates (spent = $50)

2. **Transaction from member_private wallet:**
   - Create expense: $100 from member_private wallet
   - Category: Transportation
   - Save
   - **Verify:** Budget DOES NOT update (spent still = $50)

✅ **Expected:** Only household_shared wallet transactions affect budgets

---

### Scenario 4: Budget Alert Notifications

**Goal:** Verify that notifications are sent when crossing 80%, 90%, 100% thresholds.

#### Setup
1. Create a member budget: $1000 for Member A, category: Entertainment

#### Test Steps
1. **Reach 80% threshold:**
   - Create transaction: $800
   - **Verify:** Notification appears: "Budget 80%"
   - Check Firestore `budget_usages/{budgetId}_{periodKey}`:
     - `last_alert_level_sent = 80`

2. **Reach 90% threshold:**
   - Create transaction: $100 (total $900)
   - **Verify:** Notification appears: "Budget 90%"
   - Check Firestore:
     - `last_alert_level_sent = 90`

3. **Reach 100% threshold:**
   - Create transaction: $100 (total $1000)
   - **Verify:** Notification appears: "Budget 100%"
   - Check Firestore:
     - `last_alert_level_sent = 100`

4. **Exceed budget:**
   - Create transaction: $200 (total $1200)
   - **Verify:** No new notification (already sent 100%)
   - Budget shows: Spent $1200, Over budget by $200

✅ **Expected:** Notifications sent once per threshold, in order

---

### Scenario 5: Transaction Updates

**Goal:** Verify that updating transaction amounts correctly adjusts budgets.

#### Setup
1. Create family budget: $1000 for Groceries
2. Create transaction: $200 for Groceries

#### Test Steps
1. **Initial state:**
   - Budget shows: Spent $200

2. **Edit transaction amount:**
   - Edit transaction: Change $200 → $300
   - Save
   - **Verify:** Budget shows: Spent $300 (delta +$100 applied)

3. **Edit transaction amount down:**
   - Edit transaction: Change $300 → $150
   - Save
   - **Verify:** Budget shows: Spent $150 (delta -$150 applied)

4. **Edit transaction date to next month:**
   - Edit transaction: Change date from January → February
   - Save
   - **Verify:** 
     - January budget: Spent $0 (transaction removed)
     - February budget: Spent $150 (transaction added)

✅ **Expected:** Budget updates reflect transaction edits correctly

---

### Scenario 6: Transaction Deletions

**Goal:** Verify that deleting transactions removes them from budget spending.

#### Setup
1. Create member budget: $500 for Member A, category: Food
2. Create 3 transactions:
   - Transaction A: $100
   - Transaction B: $150
   - Transaction C: $50
3. Total spent: $300

#### Test Steps
1. **Delete one transaction:**
   - Delete Transaction B ($150)
   - **Verify:** Budget shows: Spent $150 (100 + 50)

2. **Delete another transaction:**
   - Delete Transaction C ($50)
   - **Verify:** Budget shows: Spent $100

3. **Delete last transaction:**
   - Delete Transaction A ($100)
   - **Verify:** Budget shows: Spent $0

✅ **Expected:** Deletions correctly subtract from budget usage

---

### Scenario 7: Multiple Budgets Per Member

**Goal:** Verify members can have multiple budgets for different categories.

#### Setup
1. Create 3 member budgets for Member A:
   - Budget 1: $500 for Food
   - Budget 2: $300 for Entertainment
   - Budget 3: $200 for Transportation

#### Test Steps
1. **Create Food transaction:**
   - $100 for Food
   - **Verify:** Only Food budget updates (spent $100)
   - Other budgets unchanged

2. **Create Entertainment transaction:**
   - $50 for Entertainment
   - **Verify:** Only Entertainment budget updates (spent $50)
   - Food budget still shows $100

3. **Create Transportation transaction:**
   - $75 for Transportation
   - **Verify:** Only Transportation budget updates (spent $75)
   - Other budgets unchanged

✅ **Expected:** Each budget tracks its own category independently

---

### Scenario 8: Budget Period Isolation

**Goal:** Verify that budgets for different months don't affect each other.

#### Setup
1. Create monthly budget: $1000 for January 2024

#### Test Steps
1. **Create January transaction:**
   - Date: January 15, 2024
   - Amount: $300
   - **Verify:** January budget shows spent $300

2. **Create February transaction:**
   - Date: February 10, 2024
   - Amount: $400
   - **Verify:** 
     - January budget still shows $300
     - February has NO budget (not created yet)

3. **Create February budget:**
   - Create budget for February 2024: $1000
   - **Verify:** February budget shows spent $0 (historical transactions don't backfill)

4. **Create another February transaction:**
   - Date: February 15, 2024
   - Amount: $200
   - **Verify:** February budget shows spent $200

✅ **Expected:** Budgets are isolated by month (period_key)

---

## Verification Steps

### 1. Check Firestore Collections

#### budgets collection
```
budgets/{budgetId}
├─ household_id: string
├─ period_key: "YYYY-MM"
├─ budget_type: "family" | "member"
├─ member_user_id: string (if member budget)
├─ amount: number
├─ category_id: string
├─ archived: false
└─ ...
```

#### budget_usages collection
```
budget_usages/{budgetId}_{periodKey}
├─ budget_id: string
├─ household_id: string
├─ period_key: "YYYY-MM"
├─ spent_amount: number
├─ last_alert_level_sent: 0 | 80 | 90 | 100
├─ budget_type: "family" | "member"
├─ member_user_id: string (if member budget)
└─ updated_at: timestamp
```

### 2. Check Cloud Function Logs

```bash
firebase functions:log --only onTransactionCreate
```

Look for logs like:
```
[BUDGET_CF] event=create txn=xxx type=expense amount=100 eligible=true
[BUDGET_CF] matchedBudgets member=1 family=1 period=2024-01 delta=100
[BUDGET_CF_USAGE_WRITE] budget=yyy usage_doc=yyy_2024-01 spent_after=100
```

### 3. Test Budget UI

**Budget List Screen:**
- Shows all applicable budgets
- Progress bars update in real-time
- Color coding:
  - Green: Under 80%
  - Yellow: 80-99%
  - Red: 100%+

**Budget Detail Screen:**
- Shows current spending
- Shows remaining amount
- Lists recent transactions
- Updates immediately after new transaction

---

## Common Issues and Solutions

### Issue 1: Budget Not Updating

**Symptoms:**
- Transaction created
- Budget usage remains $0
- No errors shown

**Diagnosis:**
1. Check Cloud Functions logs:
   ```bash
   firebase functions:log
   ```
2. Look for `[BUDGET_CF] skip` messages
3. Check eligibility criteria:
   - Transaction type = expense ✓
   - Wallet scope = household_shared ✓
   - household_id present ✓
   - actor_user_id present ✓

**Solutions:**
- Verify transaction has all required fields
- Verify wallet scope is `household_shared`
- Check Cloud Functions are deployed

---

### Issue 2: Budget Updates But UI Doesn't Refresh

**Symptoms:**
- Firestore `budget_usages` collection updates
- App UI shows old data

**Solutions:**
1. Pull to refresh on Budget List screen
2. Navigate away and back
3. Check provider invalidation in transaction flow
4. Verify `activeBudgetsWithUsageStreamProvider` is used

---

### Issue 3: Wrong Budget Updated

**Symptoms:**
- Member A's transaction affects Member B's budget
- Or vice versa

**Diagnosis:**
1. Check transaction's `actor_user_id` field
2. Check budget's `member_user_id` field
3. Check Cloud Function logs for budget matching

**Solutions:**
- Verify `actor_user_id` is set correctly when creating transaction
- Check budget type is "member" with correct `member_user_id`

---

### Issue 4: Notifications Not Appearing

**Symptoms:**
- Budget crosses threshold (80%, 90%, 100%)
- No notification created

**Diagnosis:**
1. Check `budget_usages` document:
   - Does `last_alert_level_sent` update?
2. Check `notifications` collection:
   - Are notification documents created?
3. Check Cloud Function logs for notification creation

**Solutions:**
- Verify budget has `created_by` field (head user ID)
- Check Firestore rules allow writing to `notifications`
- Ensure notification screen reads from `notifications` collection

---

## Performance Testing

### Load Test: 100 Transactions

1. Create 100 rapid transactions
2. Verify all budgets update correctly
3. Check Cloud Function execution time
4. Monitor Firestore read/write counts

**Expected:**
- All transactions processed
- No missed budget updates
- Execution time < 2 seconds per function
- No throttling errors

---

## Regression Testing Checklist

After any changes to:
- Transaction models
- Budget models
- Cloud Functions
- Firestore rules

Run this checklist:

- [ ] Create family budget
- [ ] Create member budget
- [ ] Create expense from household_shared wallet
- [ ] Verify family budget updates
- [ ] Verify member budget updates
- [ ] Create expense from personal wallet
- [ ] Verify budgets DO NOT update
- [ ] Edit transaction amount
- [ ] Verify budget adjusts correctly
- [ ] Delete transaction
- [ ] Verify budget decreases
- [ ] Create transaction crossing 80% threshold
- [ ] Verify notification appears
- [ ] Check Firestore `budget_usages` documents
- [ ] Check Cloud Function logs

---

## Debugging Tips

### Enable Verbose Logging

Cloud Functions already have extensive logging. Search for:
- `[BUDGET_CF]` - Budget function events
- `[BUDGET_CF_USAGE_WRITE]` - Usage updates
- `[TXN_CREATE]` - Transaction creation
- `[TX_SERVICE]` - Transaction service

### Inspect Firestore Documents

Use Firebase Console to manually verify:
1. Transaction document has correct fields
2. Wallet document has correct scope
3. Budget document exists and not archived
4. Budget usage document updates correctly
5. Notification documents created at thresholds

### Test with Emulators

Run functions locally for faster debugging:
```bash
firebase emulators:start
```

Configure app to use emulator:
```dart
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

---

## Summary

The Budgets module is now fully functional with:
- ✅ Automatic transaction tracking via Cloud Functions
- ✅ Family vs. member budget isolation
- ✅ Wallet scope filtering
- ✅ Real-time UI updates
- ✅ Threshold notifications (80%, 90%, 100%)
- ✅ Transaction edit/delete handling

Follow this guide to verify all features work correctly in your deployment.
