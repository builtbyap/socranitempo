import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as cors from 'cors';
import Stripe from 'stripe';

admin.initializeApp();

// Initialize Stripe
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-05-28.basil',
});

const corsHandler = cors({
  origin: [
    'http://localhost:3000',
    'https://socrani.com',
    'https://socranitempo.vercel.app',
    'https://socrani-18328.web.app',
    'https://socrani-18328.firebaseapp.com'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
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

export const createCheckoutSession = functions.https.onRequest((req, res) => {
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
      console.log('Starting checkout session creation...');
      
      // Get the user from the request
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        console.error('No authorization header found');
        res.status(401).json({ error: 'No authorization header' });
        return;
      }

      const token = authHeader.split('Bearer ')[1];
      console.log('Verifying ID token...');
      const decodedToken = await admin.auth().verifyIdToken(token);
      const userId = decodedToken.uid;
      console.log('User authenticated:', userId);

      // Get the price ID from the request body
      const { data } = req.body;
      if (!data || !data.priceId) {
        console.error('No price ID in request body:', req.body);
        res.status(400).json({ error: 'Price ID is required' });
        return;
      }

      const { priceId } = data;
      console.log('Creating checkout session for price:', priceId);

      // Get or create the customer document
      const customerRef = admin.firestore().collection('customers').doc(userId);
      const customerDoc = await customerRef.get();

      let stripeCustomerId = customerDoc.data()?.stripeCustomerId;
      console.log('Existing Stripe customer ID:', stripeCustomerId);

      if (!stripeCustomerId) {
        console.log('Creating new Stripe customer...');
        // Create a new customer in Stripe
        const customer = await stripe.customers.create({
          email: decodedToken.email,
          metadata: {
            firebaseUID: userId
          }
        });
        stripeCustomerId = customer.id;
        console.log('New Stripe customer created:', stripeCustomerId);

        // Update the customer document with Stripe customer ID
        await customerRef.set({
          email: decodedToken.email,
          stripeCustomerId: customer.id,
          created: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }

      console.log('Creating Stripe checkout session...');
      // Create the checkout session directly with Stripe
      const session = await stripe.checkout.sessions.create({
        customer: stripeCustomerId,
        line_items: [{
          price: priceId,
          quantity: 1,
        }],
        mode: 'subscription',
        success_url: 'https://socrani.com/success',
        cancel_url: 'https://socrani.com/cancel',
        allow_promotion_codes: true,
        billing_address_collection: 'required',
        metadata: {
          firebaseUID: userId
        }
      });

      console.log('Checkout session created successfully:', session.id);
      res.json({ sessionId: session.id });
    } catch (error: any) {
      console.error('Error creating checkout session:', error);
      console.error('Error details:', {
        message: error.message,
        code: error.code,
        type: error.type,
        stack: error.stack
      });
      res.status(500).json({ 
        error: 'Internal server error',
        details: error.message,
        code: error.code,
        type: error.type,
        stack: error.stack
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