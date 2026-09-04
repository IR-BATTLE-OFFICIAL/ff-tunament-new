const crypto = require('crypto');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');

admin.initializeApp();
const db = admin.firestore();

// Configure these with Firebase Secret Manager; never put them in Flutter.
const razorpayKeyId = defineSecret('RAZORPAY_KEY_ID');
const razorpayKeySecret = defineSecret('RAZORPAY_KEY_SECRET');
const razorpayWebhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');

function razorpay() {
  return new Razorpay({key_id: razorpayKeyId.value(), key_secret: razorpayKeySecret.value()});
}

exports.createRazorpayOrder = onCall({secrets: [razorpayKeyId, razorpayKeySecret]}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const amount = Number(request.data.amount);
  if (!Number.isInteger(amount) || amount < 500 || amount > 10000000) {
    throw new HttpsError('invalid-argument', 'Invalid deposit amount.');
  }

  const user = await db.doc(`users/${request.auth.uid}`).get();
  if (!user.exists || user.get('isBlocked') === true) {
    throw new HttpsError('permission-denied', 'This account cannot add cash.');
  }

  const order = await razorpay().orders.create({
    amount,
    currency: 'INR',
    receipt: `wallet_${request.auth.uid.slice(0, 12)}_${Date.now()}`,
    notes: {userId: request.auth.uid, purpose: 'wallet_top_up'},
  });
  await db.doc(`payment_orders/${order.id}`).set({
    userId: request.auth.uid, amount, status: 'created', createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {orderId: order.id, keyId: razorpayKeyId.value()};
});

exports.confirmRazorpayPayment = onCall({secrets: [razorpayKeyId, razorpayKeySecret]}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const {razorpayPaymentId, razorpayOrderId, razorpaySignature} = request.data;
  if (![razorpayPaymentId, razorpayOrderId, razorpaySignature].every((v) => typeof v === 'string')) {
    throw new HttpsError('invalid-argument', 'Missing payment confirmation details.');
  }
  const expected = crypto.createHmac('sha256', razorpayKeySecret.value())
      .update(`${razorpayOrderId}|${razorpayPaymentId}`).digest('hex');
  if (!crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(razorpaySignature))) {
    throw new HttpsError('permission-denied', 'Invalid payment signature.');
  }
  const payment = await razorpay().payments.fetch(razorpayPaymentId);
  if (payment.order_id !== razorpayOrderId || payment.status !== 'captured') {
    throw new HttpsError('failed-precondition', 'Payment has not been captured yet.');
  }
  return creditVerifiedPayment({paymentId: razorpayPaymentId, orderId: razorpayOrderId, userId: request.auth.uid});
});

exports.razorpayWebhook = onRequest({secrets: [razorpayKeySecret, razorpayWebhookSecret]}, async (req, res) => {
  const signature = req.header('x-razorpay-signature');
  const expected = crypto.createHmac('sha256', razorpayWebhookSecret.value()).update(req.rawBody).digest('hex');
  if (!signature || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) return res.status(401).send('Invalid signature');
  if (req.body.event !== 'payment.captured') return res.status(200).send('Ignored');
  const payment = req.body.payload.payment.entity;
  try {
    await creditVerifiedPayment({paymentId: payment.id, orderId: payment.order_id, userId: payment.notes.userId});
    return res.status(200).send('OK');
  } catch (error) {
    console.error(error);
    return res.status(500).send('Retry');
  }
});

async function creditVerifiedPayment({paymentId, orderId, userId}) {
  const orderRef = db.doc(`payment_orders/${orderId}`);
  const paymentRef = db.doc(`verified_payments/${paymentId}`);
  const depositRef = db.collection('deposit_requests').doc(paymentId);
  const transactionRef = db.collection('transactions').doc(paymentId);
  let result;
  await db.runTransaction(async (tx) => {
    const [order, payment] = await Promise.all([tx.get(orderRef), tx.get(paymentRef)]);
    if (!order.exists || order.get('userId') !== userId) throw new HttpsError('permission-denied', 'Payment does not belong to this user.');
    const amount = order.get('amount');
    if (payment.exists) { result = {amount, transactionId: paymentId}; return; }
    tx.create(paymentRef, {userId, orderId, amount, verifiedAt: admin.firestore.FieldValue.serverTimestamp()});
    tx.update(orderRef, {status: 'paid', paymentId, paidAt: admin.firestore.FieldValue.serverTimestamp()});
    tx.update(db.doc(`users/${userId}`), {balance: admin.firestore.FieldValue.increment(amount / 100)});
    tx.set(depositRef, {userId, amount: amount / 100, transactionId: paymentId, razorpayOrderId: orderId, type: 'razorpay', status: 'success', dateTime: admin.firestore.FieldValue.serverTimestamp()});
    tx.set(transactionRef, {userId, amount: amount / 100, type: 'deposit', status: 'success', description: `Verified Razorpay payment (${paymentId})`, dateTime: admin.firestore.FieldValue.serverTimestamp()});
    result = {amount, transactionId: paymentId};
  });
  return result;
}
