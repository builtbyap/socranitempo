"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSubscriptionStatus = exports.createCheckoutSession = exports.createCustomer = exports.onCreateUser = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors");
admin.initializeApp();
const corsHandler = cors({
    origin: [
        'http://localhost:3000',
        'https://socrani.com',
        'https://socranitempo.vercel.app',
        'https://socrani-18328.web.app'
    ],
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
});
// Function to create a customer record when a new user signs up
exports.onCreateUser = functions.auth.user().onCreate(async (user) => {
    try {
        if (!user.email) {
            console.error('No email provided for user:', user.uid);
            return;
        }
        // Create customer document in Firestore
        await admin.firestore().collection('customers').doc(user.uid).set({
            email: user.email,
            created: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Customer document created successfully for user:', user.uid);
    }
    catch (error) {
        console.error('Error creating customer document:', error);
        throw error;
    }
});
// Function to handle customer creation via HTTP endpoint
exports.createCustomer = functions.https.onCall(async (data, context) => {
    try {
        // Check if user is authenticated
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create a customer record');
        }
        const { email } = data;
        const userId = context.auth.uid;
        if (!email) {
            throw new functions.https.HttpsError('invalid-argument', 'Email is required');
        }
        // Check if customer already exists
        const customerDoc = await admin.firestore().collection('customers').doc(userId).get();
        if (customerDoc.exists) {
            console.log('Customer already exists for user:', userId);
            return { success: true };
        }
        // Create customer document
        await admin.firestore().collection('customers').doc(userId).set({
            email,
            created: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Customer document created successfully for user:', userId);
        return { success: true };
    }
    catch (error) {
        console.error('Error creating customer:', error);
        throw new functions.https.HttpsError('internal', 'Failed to create customer record');
    }
});
exports.createCheckoutSession = functions.https.onRequest((req, res) => {
    // Set CORS headers manually
    res.set('Access-Control-Allow-Origin', 'https://socrani.com');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    return corsHandler(req, res, async () => {
        try {
            // Get the user from the request
            const authHeader = req.headers.authorization;
            if (!authHeader) {
                res.status(401).json({ error: 'No authorization header' });
                return;
            }
            const token = authHeader.split('Bearer ')[1];
            const decodedToken = await admin.auth().verifyIdToken(token);
            const userId = decodedToken.uid;
            // Get the price ID from the request body
            const { data } = req.body;
            if (!data || !data.priceId) {
                res.status(400).json({ error: 'Price ID is required' });
                return;
            }
            const { priceId } = data;
            // Get or create the customer document
            const customerRef = admin.firestore().collection('customers').doc(userId);
            const customerDoc = await customerRef.get();
            if (!customerDoc.exists) {
                // Create a new customer record
                await customerRef.set({
                    email: decodedToken.email,
                    created: admin.firestore.FieldValue.serverTimestamp(),
                    subscription: null
                });
            }
            // Create the checkout session
            const session = await customerRef
                .collection('checkout_sessions')
                .add({
                price: priceId,
                success_url: 'https://socrani.com/success',
                cancel_url: 'https://socrani.com/cancel',
                mode: 'subscription',
                allow_promotion_codes: true,
                billing_address_collection: 'required',
                customer_email: decodedToken.email,
                metadata: {
                    userId: userId
                },
                created: admin.firestore.FieldValue.serverTimestamp()
            });
            // Wait for the session to be created
            const sessionDoc = await session.get();
            const sessionData = sessionDoc.data();
            if (!(sessionData === null || sessionData === void 0 ? void 0 : sessionData.sessionId)) {
                console.error('No session ID in response:', sessionData);
                res.status(500).json({ error: 'Failed to create checkout session' });
                return;
            }
            res.json({ sessionId: sessionData.sessionId });
        }
        catch (error) {
            console.error('Error creating checkout session:', error);
            res.status(500).json({
                error: 'Internal server error',
                details: error.message,
                stack: error.stack
            });
        }
    });
});
exports.getSubscriptionStatus = functions.https.onRequest((req, res) => {
    // Set CORS headers manually
    res.set('Access-Control-Allow-Origin', 'https://socrani.com');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    return corsHandler(req, res, async () => {
        try {
            // Get the user from the request
            const authHeader = req.headers.authorization;
            if (!authHeader) {
                res.status(401).json({ error: 'No authorization header' });
                return;
            }
            const token = authHeader.split('Bearer ')[1];
            const decodedToken = await admin.auth().verifyIdToken(token);
            const userId = decodedToken.uid;
            // Get the customer's subscription
            const customerDoc = await admin.firestore()
                .collection('customers')
                .doc(userId)
                .get();
            if (!customerDoc.exists) {
                // Create a new customer record if it doesn't exist
                await admin.firestore()
                    .collection('customers')
                    .doc(userId)
                    .set({
                    email: decodedToken.email,
                    created: admin.firestore.FieldValue.serverTimestamp(),
                    subscription: null
                });
                res.json({ subscription: null });
                return;
            }
            const customerData = customerDoc.data();
            // If there's no subscription data, return null
            if (!(customerData === null || customerData === void 0 ? void 0 : customerData.subscription)) {
                res.json({ subscription: null });
                return;
            }
            // Validate subscription data
            const subscription = customerData.subscription;
            if (!subscription.status || !subscription.type) {
                res.json({ subscription: null });
                return;
            }
            res.json({ subscription });
        }
        catch (error) {
            console.error('Error getting subscription status:', error);
            res.status(500).json({
                error: 'Internal server error',
                details: error.message
            });
        }
    });
});
//# sourceMappingURL=index.js.map