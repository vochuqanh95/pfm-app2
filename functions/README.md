# Budget Tracking Cloud Functions

This directory contains Firebase Cloud Functions that automatically track budget usage when transactions are created, updated, or deleted.

## Functions

### 1. `onTransactionCreate`
Triggers when a new transaction is created.
- Adds transaction amount to relevant budget usages
- Only processes expense transactions from household_shared wallets
- Updates both family and member budgets

### 2. `onTransactionUpdate`
Triggers when a transaction is updated.
- Calculates delta between old and new amounts
- Handles changes in transaction date (month), actor, or wallet
- Removes from old budget period and adds to new period if needed

### 3. `onTransactionDelete`
Triggers when a transaction is deleted.
- Subtracts transaction amount from budget usages
- Reverses the impact on relevant budgets

## Budget Matching Logic

### Eligibility Criteria
A transaction affects budgets only if:
- ✅ Transaction type = `expense` (not income or transfer)
- ✅ Wallet scope = `household_shared` (not personal or member_private)
- ✅ Has valid `household_id`
- ✅ Has valid `actor_user_id`
- ✅ Has valid `date` (for period_key calculation)

### Budget Types

**Family Budgets:**
- Apply to ALL members' spending
- `budget_type = 'family'`
- No `member_user_id` constraint
- Example: Total household food budget of $1000/month

**Member Budgets:**
- Apply only to specific member's spending
- `budget_type = 'member'`
- Has `member_user_id` field
- Example: John's shopping budget of $500/month

### Budget Usage Storage

Budget usage is stored in `budget_usages` collection:
- Document ID: `{budgetId}_{periodKey}` (e.g., `abc123_2024-01`)
- Fields:
  - `budget_id`: Reference to budget document
  - `household_id`: For query filtering
  - `period_key`: Month in YYYY-MM format
  - `spent_amount`: Total spending so far
  - `last_alert_level_sent`: 0, 80, 90, or 100
  - `budget_type`: 'family' or 'member'
  - `member_user_id`: If member budget
  - `updated_at`: Timestamp of last update

## Notification Logic

Alerts are sent when crossing thresholds:
- **80%**: First warning
- **90%**: Second warning
- **100%**: Budget exceeded

Notifications are sent to:
- Household head (budget creator)
- Member (if it's a member budget)

Notifications are created in `notifications` collection with:
- `type: 'budget_alert'`
- `title: 'Budget {level}%'`
- `message: 'A budget hit {level}% of its limit.'`
- `related_entity_type: 'budget'`
- `related_entity_id: {budgetId}`

## Development

### Install Dependencies
```bash
npm install
```

### Build TypeScript
```bash
npm run build
```

### Test Locally
```bash
npm run serve
```

### Deploy to Firebase
```bash
npm run deploy
```

### View Logs
```bash
firebase functions:log
```

## Architecture

### Transaction Flow

1. **User creates transaction in app**
   - Flutter app writes to `transactions` collection
   - Includes: type, amount, wallet_id, actor_user_id, household_id, date

2. **Cloud Function triggers**
   - `onTransactionCreate` runs automatically
   - Fetches wallet to determine scope
   - Checks eligibility criteria

3. **Budget query**
   - Fetches member budgets for actor
   - Fetches family budgets for household
   - Filters by period_key (transaction month)

4. **Budget update**
   - For each matching budget:
     - Loads current usage from `budget_usages`
     - Adds transaction amount
     - Checks if threshold crossed
     - Updates usage document atomically

5. **Notification creation**
   - If threshold crossed (80%, 90%, 100%)
   - Creates notification documents
   - Sends to head and/or member

### Performance Optimizations

- **Wallet scope caching**: Reduces repeated lookups
- **In-memory filtering**: Avoids complex Firestore indexes
- **Transactional updates**: Ensures data consistency
- **Deterministic doc IDs**: Fast lookups without queries

## Troubleshooting

### Function Not Triggering

**Check deployment:**
```bash
firebase functions:list
```

**Check logs:**
```bash
firebase functions:log --only onTransactionCreate
```

**Common causes:**
- Functions not deployed
- Wrong Firebase project selected
- Firestore trigger not registered

### Budget Not Updating

**Check eligibility:**
- Transaction type must be "expense"
- Wallet must have scope = "household_shared"
- Transaction must have household_id and actor_user_id

**Check logs for:**
```
[BUDGET_CF] skip applyDelta eligible=false
```

### Permission Errors

**Verify Firestore rules:**
- Client can read/write transactions
- Client can read budget_usages (but NOT write)
- Functions can write budget_usages (automatic with Admin SDK)

## Testing

See `BUDGET_TESTING_GUIDE.md` in project root for comprehensive test scenarios.

Quick test:
1. Deploy functions
2. Create household with 2 members
3. Create member budget ($1000)
4. Create expense transaction ($500)
5. Check `budget_usages` collection
6. Verify `spent_amount = 500`

## Monitoring

Firebase Console → Functions → Metrics shows:
- Invocation count
- Execution time
- Error rate
- Memory usage

Expected performance:
- Execution time: <2 seconds
- Memory usage: <256MB
- Success rate: >99%

## Cost

Typical costs for small household (10 transactions/day):
- ~30 function invocations/day = ~900/month
- At $0.40 per million invocations = $0.00036/month
- Plus ~30 Firestore reads/writes per day

Total estimated cost: **~$0.10 - $0.50/month**

## Support

For issues:
1. Check function logs
2. Verify Firestore rules
3. Test with emulators
4. Review transaction data format

See main project README and CLOUD_FUNCTIONS_SETUP.md for detailed setup instructions.
