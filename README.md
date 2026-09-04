# ff_arena

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Secure wallet payments

The app uses Razorpay Checkout for wallet top-ups. The app never credits a
wallet itself: Firebase Functions verifies the Razorpay signature and captured
payment, then performs one idempotent Firestore transaction.

Before releasing, configure and deploy the functions:

```sh
cd functions
npm install
firebase functions:secrets:set RAZORPAY_KEY_ID
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
firebase deploy --only functions
```

In Razorpay Dashboard, add the deployed `razorpayWebhook` URL as a webhook,
select `payment.captured`, and use the same webhook secret. The supplied QR is
shown as a manual fallback, but only Razorpay-confirmed payments add wallet
cash automatically.
