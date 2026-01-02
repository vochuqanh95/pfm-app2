# Cloud Functions Setup and Deployment Guide

## Overview

This app uses Firebase Cloud Functions to automatically track budget usage when transactions are created, updated, or deleted. The functions are written in TypeScript and deployed to Firebase.

## Prerequisites

1. **Node.js 18** or later installed
2. **Firebase CLI** installed globally:
   ```bash
   npm install -g firebase-tools
   ```
3. **Firebase project** configured (see main README.md)
4. **Admin access** to the Firebase project

## Initial Setup

### 1. Install Dependencies

Navigate to the functions directory and install packages:

```bash
cd functions
npm install
```

This installs:
- `firebase-admin`: Firebase Admin SDK
- `firebase-functions`: Cloud Functions SDK
- `typescript`: TypeScript compiler

### 2. Login to Firebase

If not already logged in:

```bash
firebase login
```

### 3. Verify Firebase Project

Check that you're connected to the correct project:

```bash
firebase use
```

To switch projects:

```bash
firebase use <project-id>
```

## Building the Functions

Before deployment, compile TypeScript to JavaScript:

```bash
cd functions
npm run build
```

This creates the `lib/` directory with compiled JavaScript files.

## Deployment

### Deploy All Functions

```bash
cd functions
npm run deploy
```

Or from the project root:

```bash
firebase deploy --only functions
```

### Deploy Specific Function

To deploy only one function (faster for updates):

```bash
firebase deploy --only functions:onTransactionCreate
firebase deploy --only functions:onTransactionUpdate
firebase deploy --only functions:onTransactionDelete
```

### Verify Deployment

After deployment, check the Firebase Console:
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Functions** in the left sidebar
4. Verify all three functions are listed:
   - `onTransactionCreate`
   - `onTransactionUpdate`
   - `onTransactionDelete`
5. Check that they have recent deployment timestamps

## How Budget Tracking Works

### Transaction Triggers

The Cloud Functions automatically run when:

1. **Transaction Created** (`onTransactionCreate`)
   - Adds transaction amount to budget usage
   - Only for expense transactions from `household_shared` wallets
   - Updates both family and member budgets

2. **Transaction Updated** (`onTransactionUpdate`)
   - Calculates the delta (new amount - old amount)
   - Applies delta to relevant budgets
   - Handles period/actor/wallet changes

3. **Transaction Deleted** (`onTransactionDelete`)
   - Subtracts transaction amount from budget usage
   - Reverses the budget impact

### Budget Matching Logic

For each transaction, the function:

1. **Checks Eligibility:**
   - Type = `expense` (not income or transfer)
   - Wallet scope = `household_shared` (not personal)
   - Has valid `household_id` and `period_key`

2. **Fetches Member Budgets:**
   - Queries budgets where:
     - `household_id` matches transaction
     - `period_key` matches transaction month (YYYY-MM)
     - `budget_type = 'member'`
     - `member_user_id` matches transaction actor
     - `archived = false`

3. **Fetches Family Budgets:**
   - Queries budgets where:
     - `household_id` matches transaction
     - `period_key` matches transaction month
     - `budget_type = 'family'`
     - `archived = false`

4. **Updates Budget Usage:**
   - Creates/updates document in `budget_usages` collection
   - Document ID format: `{budgetId}_{periodKey}`
   - Stores:
     - `spent_amount`: Current total spending
     - `last_alert_level_sent`: 0, 80, 90, or 100
     - `updated_at`: Timestamp

5. **Sends Notifications:**
   - Checks if spending crosses 80%, 90%, or 100% thresholds
   - Creates notification documents for:
     - Household head (budget creator)
     - Member (if it's a member budget)

## Testing Functions Locally

### Using Firebase Emulators

Run functions locally without deploying:

```bash
cd functions
npm run serve
```

This starts the Functions emulator. The Firestore emulator can also be started:

```bash
firebase emulators:start
```

Connect your Flutter app to emulators by updating Firebase configuration to use localhost.

### Manual Testing After Deployment

1. **Create a Budget:**
   - Log in as household head
   - Navigate to Budgets → Add Budget
   - Create a member budget: $1000/month for a specific member
   - Note the budget ID from Firestore

2. **Create a Transaction:**
   - Log in as the member
   - Navigate to Transactions → Add Expense
   - Amount: $100
   - Wallet: Select a `household_shared` wallet
   - Save transaction

3. **Verify Budget Usage:**
   - Go to Firestore Console
   - Collection: `budget_usages`
   - Find document: `{budgetId}_{YYYY-MM}`
   - Verify:
     - `spent_amount = 100`
     - `budget_id = {budgetId}`
     - `household_id = {householdId}`
     - `updated_at` is recent

4. **Verify in App:**
   - Go to Budgets screen
   - Budget should show:
     - Spent: $100
     - Remaining: $900
     - Progress bar at 10%

5. **Test Threshold Alerts:**
   - Create transaction for $700 more (total $800, 80%)
   - Check Notifications → should have "Budget 80%" alert
   - Create transaction for $100 more (total $900, 90%)
   - Check Notifications → should have "Budget 90%" alert
   - Create transaction for $100 more (total $1000, 100%)
   - Check Notifications → should have "Budget 100%" alert

## Troubleshooting

### Functions Not Triggering

**Problem:** Transactions created but budget usage not updating

**Solutions:**
1. Check Functions are deployed:
   ```bash
   firebase functions:list
   ```
2. Check Function logs:
   ```bash
   firebase functions:log
   ```
3. Verify Firestore rules allow reading/writing `budget_usages`
4. Check transaction has required fields:
   - `type = 'expense'`
   - `wallet_id` points to wallet with `scope = 'household_shared'`
   - `household_id` is set
   - `actor_user_id` is set

### Permission Denied Errors

**Problem:** Function fails with permission errors

**Solutions:**
1. Verify Firestore rules in `firestore.rules`
2. Check `budget_usages` rules allow functions to write:
   ```
   match /budget_usages/{usageId} {
     allow read: if <conditions>;
     allow create, update, delete: if false; // Client cannot write
   }
   ```
3. Ensure Firebase Admin SDK has proper permissions (should be automatic)

### Missing Budget Usage Data

**Problem:** Old transactions don't have budget usage

**Solutions:**
- Functions only trigger on NEW events (create/update/delete)
- To backfill data, you would need to:
  1. Write a one-time migration function
  2. Or manually update `budget_usages` documents

### Logs Not Showing

**Problem:** Can't see function execution logs

**Solutions:**
1. View logs in Firebase Console:
   - Go to Functions → Select function → Logs tab
2. Use CLI:
   ```bash
   firebase functions:log --only onTransactionCreate
   ```
3. Check for runtime errors in Functions dashboard

## Monitoring

### View Function Metrics

Firebase Console → Functions → Select a function

Monitor:
- **Invocations**: How many times triggered
- **Execution time**: Average duration
- **Memory usage**: RAM consumption
- **Error rate**: Failed executions

### Budget-Specific Logs

Functions write debug logs prefixed with:
- `[BUDGET_CF]` - General budget function logs
- `[BUDGET_CF_USAGE_WRITE]` - Budget usage document updates
- `[BUDGET_USAGE]` - Budget usage queries

Search logs for these prefixes to debug budget tracking.

## Cost Considerations

### Free Tier (Spark Plan)

Cloud Functions are **NOT available** on the free tier. You need:
- **Blaze Plan** (pay-as-you-go)

### Typical Costs

For a small family (5-10 transactions/day):
- **Invocations**: ~10-20 per day = ~300-600/month
- **Compute time**: <1 second per invocation
- **Monthly cost**: ~$0.10 - $0.50

For more details: https://firebase.google.com/pricing

## CI/CD Integration

### Automated Deployment

Add to your CI/CD pipeline:

```yaml
# Example GitHub Actions
- name: Deploy Functions
  run: |
    npm install -g firebase-tools
    cd functions
    npm install
    npm run build
    firebase deploy --only functions --token ${{ secrets.FIREBASE_TOKEN }}
```

### Generating CI Token

```bash
firebase login:ci
```

Save the token as a secret in your CI/CD platform.

## Best Practices

1. **Always build before deploying:**
   ```bash
   cd functions
   npm run build && npm run deploy
   ```

2. **Test locally first:**
   - Use emulators during development
   - Deploy to production only after testing

3. **Monitor function performance:**
   - Check execution time regularly
   - Optimize slow functions
   - Set up alerts for high error rates

4. **Review logs after changes:**
   - Deploy a change
   - Create a test transaction
   - Check logs to verify function ran correctly

5. **Keep dependencies updated:**
   ```bash
   cd functions
   npm outdated
   npm update
   ```

## Additional Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [TypeScript for Cloud Functions](https://firebase.google.com/docs/functions/typescript)
- [Local Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Monitoring Functions](https://firebase.google.com/docs/functions/monitoring)

## Support

If budget tracking is not working after following this guide:
1. Check Firebase Console logs
2. Verify all prerequisites are met
3. Review Firestore rules
4. Check transaction data format
5. Test with emulators first
