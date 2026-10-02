# flutter_application_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Budgetmate2
# Budgetmate2


## Firebase backend (September 2026)

Project: `budgetmate-app-a94da`. Authentication uses Firebase Auth; profiles are
`users/{uid}`, entries are `transactions/{id}` and goals are `goals/{id}` with
`user_id` ownership. Custom categories now use `users/{uid}/categories/{id}`;
default categories ship with the app so startup needs no unauthenticated writes.
Legacy custom categories in the root `categories` collection are not automatically
migrated because they have no reliable owner; an administrator must assign them
to the correct user before copying them. Existing transactions and goals retain
their paths. Goal transfers commit the expense and goal update atomically.
The available-balance check is still client-side, so this is a personal expense
tracker, not a payment or banking ledger. Receipt paths remain device-local.

From the repository root deploy with:
```sh
firebase deploy --only firestore --project budgetmate-app-a94da
```
Enable Email/Password and (if needed) Google in Firebase Authentication.
For Google login verify platform OAuth configuration and Android SHA fingerprints.
Use Firebase Console to administer data. There is no separate admin dashboard.
After deployment, test with two accounts: create an entry and goal, restart and
sign in again, transfer savings, and verify that the other account cannot read
or modify the first account's records. The service regression tests in `test/data_service_test.dart` use an in-memory
database; they do not replace Firebase integration or Security Rules tests.

References: https://firebase.google.com/docs/firestore/security/rules-query
and https://firebase.google.com/docs/firestore/manage-data/transactions

Database verification (2026-09-07): the existing database ID is `default`
(without parentheses), in `asia-southeast3`. The earlier CLI attempt targeted
`(default)`, which does not exist. No new database or billing upgrade is needed
to target the existing database. DBHelper and both Firebase CLI configurations
now explicitly select `default`.

## Android release APK

Use the same Flutter SDK as `dart.flutterSdkPath` in VS Code. On this Mac,
Homebrew's `flutter` is a different version; select the project SDK first:

```sh
export PATH="/Users/promporn/flutter/flutter/bin:$PATH"
cd /Users/promporn/Desktop/Budgetmate2/flutter_application_1
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.
Gradle uses an English/US build-time locale to avoid Buddhist-calendar ZIP
timestamp errors on Thai macOS. This does not change the app's language.
Persisted category and goal icons are resolved through `lib/models/persisted_icons.dart`;
keep old entries and add new picker icons there so release font tree-shaking works.
The release build currently uses the debug signing key for local installation.
