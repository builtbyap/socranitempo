import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as cors from 'cors';
import Stripe from 'stripe';

admin.initializeApp();

const corsHandler = cors({ origin: true });

// Initialize Stripe with Firebase config
const stripeSecretKey = functions.config().stripe?.secret_key;
if (!stripeSecretKey) {
  throw new Error('Stripe secret key is not configured. Please set it using: firebase functions:config:set stripe.secret_key="YOUR_STRIPE_SECRET_KEY"');
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: '2023-10-16',
});

// Function to create a customer record when a new user signs up
export const onCreateUser = functions.auth.user().onCreate(async (user) => {
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
  } catch (error) {
    console.error('Error creating customer document:', error);
    throw error;
  }
});

// Function to handle customer creation via HTTP endpoint
export const createCustomer = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to create a customer record'
      );
    }

    const { email } = data;
    const userId = context.auth.uid;

    if (!email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email is required'
      );
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
  } catch (error) {
    console.error('Error creating customer:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create customer record'
    );
  }
});

export const createCheckoutSession = functions.https.onRequest(async (req, res) => {
  return corsHandler(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      console.log('Request body:', req.body); // Log the request body for debugging

      const { priceId, successUrl, cancelUrl } = req.body;

      if (!priceId) {
        res.status(400).json({ error: 'Price ID is required' });
        return;
      }

      // Get the origin from the request headers
      const origin = req.headers.origin || 'http://localhost:3000';
      
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
      });

      res.status(200).json({ sessionId: session.id });
    } catch (error) {
      console.error('Error creating checkout session:', error);
      res.status(500).json({ 
        error: 'Failed to create checkout session',
        details: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

export const getSubscriptionStatus = functions.https.onRequest((req, res) => {
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
      if (!customerData?.subscription) {
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
    } catch (error: any) {
      console.error('Error getting subscription status:', error);
      res.status(500).json({ 
        error: 'Internal server error',
        details: error.message
      });
    }
  });
}); 