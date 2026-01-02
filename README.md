# FamilyWealth - Personal Finance Management App

A comprehensive Personal Finance Management (PFM) application built with Flutter and Firebase, designed to help individuals and small families track, control, and optimize their spending, saving, and financial planning.

## Features

### 🏠 Household Management
- Create and manage household groups with up to 7 members
- Role-based permissions (Head of Household / Member)
- Shared and private wallets
- Member spending tracking and budgets

### 💰 Financial Tracking
- Multi-account support (Cash, Bank, Credit Card, E-Wallet)
- Income, expense, and transfer transactions
- Recurring transactions
- Receipt OCR with Google ML Kit
- Multi-currency support

### 📊 Budgets & Goals
- **Category-based budgeting** - Set spending limits per category
- **Family-wide budgets** - Track total household spending
- **Per-member budgets** - Monitor individual member expenses
- **Automatic tracking** - Budgets update in real-time via Cloud Functions
- **Smart alerts** - Get notified at 80%, 90%, and 100% thresholds
- **Savings goals** with progress tracking and contributions

### 📈 Reports & Analytics
- Visual spending charts
- Income vs expense comparison
- Category-wise breakdown
- Member spending analysis
- Export to CSV/XLSX

### 📅 Bills & Reminders
- Recurring bill management
- Due date reminders
- Automatic payment tracking

### 🔐 Security & Authentication
- Email and Google Sign-In
- Two-factor authentication (2FA)
- Bank-level encryption (AES-256)
- Offline-first with sync

## Technology Stack

- **Frontend**: Flutter 3.x
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions)
- **State Management**: Riverpod
- **Routing**: go_router
- **Charts**: FL Chart, Syncfusion Charts
- **OCR**: Google ML Kit
- **Cloud Functions**: TypeScript (Node.js 18)

## Project Structure

```
lib/
├── core/
│   ├── routes/          # App routing configuration
│   └── theme/           # Theme and colors
├── data/
│   ├── models/          # Data models (User, Wallet, Transaction, etc.)
│   ├── repositories/    # Data repositories
│   └── services/        # Firebase services
├── presentation/
│   ├── screens/         # App screens
│   │   ├── splash/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── wallet/
│   │   ├── goals/
│   │   ├── bills/
│   │   ├── debts/
│   │   └── reports/
│   └── widgets/         # Reusable widgets
└── main.dart            # App entry point
```

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter 3.0 or higher
   ```bash
   flutter --version
   ```

2. **Firebase CLI**: Install Firebase CLI
   ```bash
   npm install -g firebase-tools
   ```

3. **FlutterFire CLI**: Install FlutterFire CLI
   ```bash
   dart pub global activate flutterfire_cli
   ```

### Installation Steps

1. **Clone the repository** (if applicable) or navigate to the project directory
   ```bash
   cd c:\Users\vochu\Downloads\stitch_splash_screen
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   a. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)

   b. Enable the following Firebase services:
      - Authentication (Email/Password, Google)
      - Cloud Firestore
      - Cloud Storage

   c. Run FlutterFire configuration:
   ```bash
   flutterfire configure
   ```

   This will:
   - Create a Firebase app for Android and iOS
   - Download configuration files
   - Update `lib/firebase_options.dart`

4. **Set up Firestore Security Rules**

   Copy the rules from `firestore.rules` file in the project root:
   ```bash
   firebase deploy --only firestore:rules
   ```

   Or manually copy the content to Firebase Console > Firestore Database > Rules.

5. **Deploy Cloud Functions (Required for Budget Tracking)**

   ⚠️ **IMPORTANT**: The Budgets feature requires Cloud Functions to be deployed. Without them, budget usage will not update when transactions are created.

   a. Upgrade to Firebase Blaze Plan (pay-as-you-go):
      - Go to Firebase Console > Project Settings > Usage and billing
      - Click "Modify plan" and select Blaze
      - *Note: Small usage (5-10 transactions/day) costs ~$0.10-0.50/month*

   b. Deploy the functions:
   ```bash
   # Quick deploy
   ./scripts/deploy-functions.sh
   
   # Or manual deploy
   cd functions
   npm install
   npm run build
   npm run deploy
   ```

   c. Verify deployment:
   ```bash
   firebase functions:list
   ```
   
   You should see:
   - `onTransactionCreate`
   - `onTransactionUpdate`
   - `onTransactionDelete`

   **📖 See [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md) for detailed instructions**

6. **Run the app**
   ```bash
   # For Android
   flutter run

   # For iOS (on macOS)
   flutter run -d ios

   # For Web
   flutter run -d chrome
   ```

## Firebase Configuration

### Firestore Collections Structure

The app uses the following Firestore collections based on the ERD:

- `users` - User profiles
- `households` - Household groups
- `household_members` - Household membership
- `wallets` - Financial accounts
- `categories` - Transaction categories
- `transactions` - Income/expense/transfer records
- `budgets` - Budget tracking
- `goals` - Savings goals
- `goal_contributions` - Goal contribution history
- `bills` - Bill reminders
- `debts` - Debt tracking
- `debt_payments` - Debt payment history
- `notifications` - User notifications
- `approvals` - Transaction approval requests

### Authentication Setup

1. Go to Firebase Console > Authentication > Sign-in method
2. Enable:
   - Email/Password
   - Google (add OAuth client IDs)

### Storage Setup

1. Go to Firebase Console > Storage
2. Set up storage rules for receipt images:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /receipts/{userId}/{allPaths=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

## Development

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/models/user_model_test.dart
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Key Features Implementation

### 1. Budget Tracking System

The Budgets feature automatically tracks spending against limits set by the household head:

**How It Works:**
1. **Head creates budget**: Set spending limits per category (family-wide or per-member)
2. **Member creates transaction**: When any member makes an expense from a shared wallet
3. **Cloud Function triggers**: Automatically updates budget usage in real-time
4. **Notifications sent**: Alerts at 80%, 90%, and 100% thresholds
5. **UI updates**: Budget cards show current spending and remaining amounts

**Budget Types:**
- **Family Budgets**: Track total household spending (all members combined)
- **Member Budgets**: Track individual member spending only

**Technical Implementation:**
- **Cloud Functions** (`functions/src/index.ts`):
  - `onTransactionCreate`: Adds transaction to budget usage
  - `onTransactionUpdate`: Adjusts budget for amount changes
  - `onTransactionDelete`: Removes transaction from budget usage
- **Firestore Collections**:
  - `budgets`: Stores budget definitions
  - `budget_usages`: Stores denormalized spending totals (updated by functions)
- **Filtering**: Only expenses from `household_shared` wallets count toward budgets

**📖 See [BUDGET_TESTING_GUIDE.md](BUDGET_TESTING_GUIDE.md) for complete testing instructions**

### 2. Role-Based Access
- Head of Household: Full access to all features
- Members: Limited access based on permissions

### 3. Offline Support
- Local caching with Firestore offline persistence
- Automatic sync when online

### 4. Multi-Currency
- Support for multiple currencies
- Exchange rate handling for transfers

### 4. OCR Receipt Scanning
- Google ML Kit integration
- Automatic amount and date extraction

### 5. Recurring Transactions
- Daily, weekly, monthly, yearly frequencies
- Automatic transaction generation

## Performance Requirements

- Transaction add: < 300ms
- Report load: < 3s
- Offline-first operation
- Real-time sync

## Security

- AES-256 encryption
- HTTPS only
- Firebase security rules
- Two-factor authentication

## Platform Support

- Android 9+ (API level 28+)
- iOS 14+
- Web (modern browsers)

## Troubleshooting

### Common Issues

1. **Firebase configuration errors**
   - Re-run `flutterfire configure`
   - Check `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

2. **Package conflicts**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Build errors**
   ```bash
   flutter doctor
   flutter pub upgrade
   ```

4. **Budget not updating after transaction**
   - ✅ Verify Cloud Functions are deployed: `firebase functions:list`
   - ✅ Check function logs: `firebase functions:log`
   - ✅ Ensure Firebase project is on Blaze plan (Cloud Functions require it)
   - ✅ Verify transaction uses `household_shared` wallet
   - ✅ Check transaction has `actor_user_id` and `household_id` fields
   - 📖 See [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md) for details

5. **Budget notifications not appearing**
   - Check Firestore `budget_usages` collection for `last_alert_level_sent` field
   - Verify `notifications` collection has new documents
   - Check function logs for notification creation errors
   ```bash
   flutter doctor
   flutter pub upgrade
   ```

## Contributing

1. Follow the existing code structure
2. Use meaningful variable and function names
3. Add comments for complex logic
4. Write tests for new features
5. Update README for new features

## License

This project is for educational purposes.

## Support

For issues and questions:
- Check Firebase Console for backend errors
- Review Flutter logs: `flutter logs`
- Check Firestore rules and indexes
- **Budget issues**: See [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md) and [BUDGET_TESTING_GUIDE.md](BUDGET_TESTING_GUIDE.md)

## Documentation

- **[CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md)** - How to deploy Cloud Functions for budget tracking
- **[BUDGET_TESTING_GUIDE.md](BUDGET_TESTING_GUIDE.md)** - Complete testing guide for Budgets feature
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Goals and Bills feature implementation details
- **[FIXES_SUMMARY.md](FIXES_SUMMARY.md)** - Remaining known issues

## Roadmap

- [ ] Budget forecast AI
- [ ] Investment tracking
- [ ] Tax calculation
- [ ] Financial advisor chatbot
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Backup/restore functionality

---

Built with Flutter & Firebase ❤️
