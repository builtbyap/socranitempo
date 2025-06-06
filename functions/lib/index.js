"use strict";
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSubscriptionStatus = exports.createCheckoutSession = exports.createCustomer = exports.onCreateUser = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors");
const stripe_1 = require("stripe");
admin.initializeApp();
const corsHandler = cors({
    origin: ['https://socrani.com', 'http://localhost:3000'],
    methods: ['GET', 'POST', 'OPTIONS'],
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization']
});
// Initialize Stripe with Firebase config
const stripeSecretKey = (_a = functions.config().stripe) === null || _a === void 0 ? void 0 : _a.secret_key;
if (!stripeSecretKey) {
    throw new Error('Stripe secret key is not configured. Please set it using: firebase functions:config:set stripe.secret_key="YOUR_STRIPE_SECRET_KEY"');
}
const stripe = new stripe_1.default(stripeSecretKey, {
    apiVersion: '2023-10-16',
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
exports.createCheckoutSession = functions.https.onRequest(async (req, res) => {
    return corsHandler(req, res, async () => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }
            // Log the entire request for debugging
            console.log('Request headers:', req.headers);
            console.log('Request body:', req.body);
            console.log('Request query:', req.query);
            // Extract data from the request
            const { data } = req.body;
            if (!data) {
                console.error('No data provided in request body');
                res.status(400).json({
                    error: 'Request data is required',
                    data: null
                });
                return;
            }
            const { priceId, successUrl, cancelUrl } = data;
            if (!priceId) {
                console.error('No priceId provided in request data');
                res.status(400).json({
                    error: 'Price ID is required',
                    data: null
                });
                return;
            }
            // Validate the price ID with Stripe
            try {
                const price = await stripe.prices.retrieve(priceId);
                console.log('Validated price:', price);
            }
            catch (error) {
                console.error('Invalid price ID:', error);
                res.status(400).json({
                    error: 'Invalid price ID',
                    details: error instanceof Error ? error.message : 'Unknown error',
                    data: null
                });
                return;
            }
            // Get the origin from the request headers
            const origin = req.headers.origin || 'https://socrani.com';
            // Create the checkout session
            const session = await stripe.checkout.sessions.create({
                payment_method_types: ['card'],
                line_items: [
                    {
                        price: priceId,
                        quantity: 1,
                    },
                ],
                mode: 'subscription',
                success_url: successUrl || `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
                cancel_url: cancelUrl || `${origin}/cancel`,
                billing_address_collection: 'required',
                customer_email: data.customerEmail,
            });
            console.log('Created checkout session:', session.id);
            // Format response for httpsCallable
            res.status(200).json({
                data: {
                    sessionId: session.id
                }
            });
        }
        catch (error) {
            console.error('Error creating checkout session:', error);
            res.status(500).json({
                error: 'Failed to create checkout session',
                details: error instanceof Error ? error.message : 'Unknown error',
                code: error instanceof Error ? error.name : 'Unknown',
                data: null
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