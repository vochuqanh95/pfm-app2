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
- Category-based budgeting
- Family-wide and per-member budgets
- Savings goals with progress tracking
- Budget alerts (80%, 90%, 100%)

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
- **Backend**: Firebase (Firestore, Auth, Storage)
- **State Management**: Riverpod
- **Routing**: go_router
- **Charts**: FL Chart, Syncfusion Charts
- **OCR**: Google ML Kit

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

   Go to Firebase Console > Firestore Database > Rules and add:

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Users collection
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }

       // Households collection
       match /households/{householdId} {
         allow read: if request.auth != null &&
           exists(/databases/$(database)/documents/household_members/$(request.auth.uid + '_' + householdId));
         allow write: if request.auth != null;
       }

       // Wallets collection
       match /wallets/{walletId} {
         allow read, write: if request.auth != null;
       }

       // Transactions collection
       match /transactions/{transactionId} {
         allow read, write: if request.auth != null;
       }

       // Categories, Budgets, Goals, Bills, Debts
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

5. **Run the app**
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

### 1. Role-Based Access
- Head of Household: Full access to all features
- Members: Limited access based on permissions

### 2. Offline Support
- Local caching with Firestore offline persistence
- Automatic sync when online

### 3. Multi-Currency
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
