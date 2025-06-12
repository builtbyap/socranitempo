import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as cors from 'cors';
import Stripe from 'stripe';

admin.initializeApp();

const corsHandler = cors({
  origin: ['https://socrani.com', 'http://localhost:3000', 'https://socranitempo.vercel.app'],
  methods: ['GET', 'POST', 'OPTIONS'],
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization', 'Origin', 'Accept']
});

// Initialize Stripe with Firebase config
const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2023-10-16',
});

// Helper function to handle CORS
const handleCors = (req: functions.https.Request, res: functions.Response) => {
  return new Promise((resolve, reject) => {
    corsHandler(req, res, (result: any) => {
      if (result instanceof Error) {
        return reject(result);
      }
      return resolve(result);
    });
  });
};

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

export const createCheckoutSession = functions.https.onCall(async (data, context) => {
  try {
    // Log the incoming request data
    console.log("Received request data:", data);
    console.log("Auth context:", context.auth);

    // Check if user is authenticated
    if (!context.auth) {
      console.error("No authenticated user found");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to create a checkout session"
      );
    }

    // Check if Stripe secret key is configured
    const stripeSecretKey = functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      console.error("Stripe secret key is not configured");
      throw new functions.https.HttpsError(
        "internal",
        "Stripe configuration is missing"
      );
    }

    // Check if app URL is configured
    const appUrl = functions.config().app?.url;
    if (!appUrl) {
      console.error("App URL is not configured");
      throw new functions.https.HttpsError(
        "internal",
        "App URL configuration is missing"
      );
    }

    const { priceId } = data;
    console.log("Price ID:", priceId);

    // Validate price ID
    if (!priceId || typeof priceId !== "string") {
      console.error("Invalid price ID:", priceId);
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Price ID is required and must be a string"
      );
    }

    if (!priceId.startsWith("price_")) {
      console.error("Invalid price ID format:", priceId);
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid price ID format"
      );
    }

    // Get user email
    const user = await admin.auth().getUser(context.auth.uid);
    console.log("User details:", user);

    if (!user.email) {
      console.error("User has no email:", user);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "User must have an email address"
      );
    }

    // Get or create Stripe customer
    const customersRef = admin.firestore().collection('customers');
    const customerDoc = await customersRef.doc(context.auth.uid).get();
    let customerId;

    if (customerDoc.exists && customerDoc.data()?.stripeCustomerId) {
      customerId = customerDoc.data()?.stripeCustomerId;
      console.log("Found existing Stripe customer:", customerId);
    } else {
      try {
        // Create new Stripe customer
        const customer = await stripe.customers.create({
          email: user.email,
          metadata: {
            firebaseUID: context.auth.uid
          }
        });
        customerId = customer.id;
        console.log("Created new Stripe customer:", customerId);

        // Create customer portal session
        const portalSession = await stripe.billingPortal.sessions.create({
          customer: customerId,
          return_url: `${appUrl}/dashboard`
        });

        // Save Stripe customer ID and portal link to Firestore
        await customersRef.doc(context.auth.uid).set({
          stripeCustomerId: customerId,
          stripeCustomerLink: portalSession.url,
          email: user.email,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (error) {
        console.error("Error creating Stripe customer:", error);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to create Stripe customer",
          error
        );
      }
    }

    // Create checkout session
    try {
      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        payment_method_types: ["card"],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        success_url: `${appUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${appUrl}/pricing`,
        customer: customerId,
        metadata: {
          userId: context.auth.uid,
        },
      });

      console.log("Created checkout session:", session);

      return {
        sessionId: session.id,
        url: session.url,
      };
    } catch (error) {
      console.error("Error creating checkout session:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create checkout session",
        error
      );
    }
  } catch (error) {
    console.error("Unexpected error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "An unexpected error occurred",
      error
    );
  }
});

// Add a new HTTP function for direct API calls
export const createCheckoutSessionHttp = functions.https.onRequest(async (req, res) => {
  try {
    // Handle CORS
    await handleCors(req, res);

    // Only allow POST requests
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Get the Firebase ID token from the Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).send('Unauthorized');
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error('Error verifying ID token:', error);
      res.status(401).send('Invalid ID token');
      return;
    }

    const { priceId } = req.body;
    if (!priceId) {
      res.status(400).send('Price ID is required');
      return;
    }

    // Get user email
    const user = await admin.auth().getUser(decodedToken.uid);
    if (!user.email) {
      res.status(400).send('User must have an email address');
      return;
    }

    // Get or create Stripe customer
    const customersRef = admin.firestore().collection('customers');
    const customerDoc = await customersRef.doc(decodedToken.uid).get();
    let customerId;

    if (customerDoc.exists && customerDoc.data()?.stripeCustomerId) {
      customerId = customerDoc.data()?.stripeCustomerId;
      console.log("Found existing Stripe customer:", customerId);
    } else {
      try {
        // Create new Stripe customer
        const customer = await stripe.customers.create({
          email: user.email,
          metadata: {
            firebaseUID: decodedToken.uid
          }
        });
        customerId = customer.id;
        console.log("Created new Stripe customer:", customerId);

        // Create customer portal session
        const portalSession = await stripe.billingPortal.sessions.create({
          customer: customerId,
          return_url: `${functions.config().app.url}/dashboard`
        });

        // Save Stripe customer ID and portal link to Firestore
        await customersRef.doc(decodedToken.uid).set({
          stripeCustomerId: customerId,
          stripeCustomerLink: portalSession.url,
          email: user.email,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (error) {
        console.error("Error creating Stripe customer:", error);
        res.status(500).send('Failed to create Stripe customer');
        return;
      }
    }

    // Create checkout session
    try {
      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        payment_method_types: ["card"],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        success_url: `${functions.config().app.url}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${functions.config().app.url}/pricing`,
        customer: customerId,
        metadata: {
          userId: decodedToken.uid,
        },
      });

      res.status(200).json({
        sessionId: session.id,
        url: session.url,
      });
    } catch (error) {
      console.error("Error creating checkout session:", error);
      res.status(500).send('Failed to create checkout session');
    }
  } catch (error) {
    console.error("Unexpected error:", error);
    res.status(500).send('An unexpected error occurred');
  }
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

export const handleSuccessfulPayment = functions.https.onRequest(async (req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  // Set CORS headers for all responses
  res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Credentials', 'true');

  // Wrap the CORS handler in a promise
  await new Promise((resolve, reject) => {
    corsHandler(req, res, (err) => {
      if (err) reject(err);
      resolve(true);
    });
  });

  try {
    // Check if Stripe secret key is configured
    const stripeSecretKey = functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      console.error("Stripe secret key is not configured");
      throw new Error("Stripe configuration is missing");
    }

    // Initialize Stripe with the secret key
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16',
    });

    // Get the session ID from the request body
    const { sessionId } = req.body;
    if (!sessionId) {
      throw new Error("No session ID provided");
    }

    console.log("Processing payment for session:", sessionId);

    // Retrieve the session from Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    if (!session) {
      throw new Error("Session not found");
    }

    console.log("Session retrieved:", {
      id: session.id,
      status: session.status,
      customer: session.customer,
      subscription: session.subscription
    });

    // Get the customer ID and subscription ID from the session
    const customerId = session.customer as string;
    const subscriptionId = session.subscription as string;

    if (!customerId || !subscriptionId) {
      throw new Error("Invalid session data");
    }

    // Get the customer details from Stripe
    const customer = await stripe.customers.retrieve(customerId);
    if (!customer || customer.deleted) {
      throw new Error("Customer not found in Stripe");
    }

    // Get the customer portal URL
    const portalSession = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: 'https://socrani.com/dashboard'
    });

    // Get the subscription details
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    console.log("Subscription retrieved:", {
      id: subscription.id,
      status: subscription.status,
      currentPeriodEnd: subscription.current_period_end
    });

    const priceId = subscription.items.data[0].price.id;
    const productId = subscription.items.data[0].price.product as string;

    // Get the product details
    const product = await stripe.products.retrieve(productId);
    const tier = product.metadata.tier || "basic";

    console.log("Product details:", {
      id: product.id,
      name: product.name,
      tier: tier
    });

    // Get the user ID from the session metadata
    const userId = session.metadata?.userId;
    if (!userId) {
      throw new Error("No user ID found in session metadata");
    }

    // Get the user's email from Firebase Auth
    const userRecord = await admin.auth().getUser(userId);
    const userEmail = userRecord.email;

    if (!userEmail) {
      throw new Error("User email not found");
    }

    // Create a batch write to ensure atomic updates
    const batch = admin.firestore().batch();

    // Update the customer document with subscription info and additional details
    const customerRef = admin.firestore().collection('customers').doc(userId);
    const customerData = {
      email: userEmail,
      stripeCustomerId: customerId,
      stripeCustomerLink: portalSession.url,
      stripeSubscriptionId: subscriptionId,
      stripePriceId: priceId,
      stripeProductId: productId,
      subscriptionStatus: subscription.status,
      subscriptionTier: tier,
      subscriptionStartDate: admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000),
      subscriptionEndDate: admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    console.log("Updating customer document with data:", customerData);
    batch.set(customerRef, customerData, { merge: true });

    // Create/update the subscription document
    const subscriptionRef = customerRef.collection('subscriptions').doc(subscriptionId);
    const subscriptionData = {
      status: subscription.status,
      priceId: priceId,
      productId: productId,
      tier: tier,
      currentPeriodStart: admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000),
      currentPeriodEnd: admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
      createdAt: admin.firestore.Timestamp.fromMillis(subscription.created * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    console.log("Updating subscription document with data:", subscriptionData);
    batch.set(subscriptionRef, subscriptionData);

    // Commit the batch
    await batch.commit();
    console.log("Successfully committed batch updates to Firestore");

    // Send success response
    res.status(200).json({
      success: true,
      subscription: {
        customerId,
        subscriptionId,
        priceId,
        productId,
        tier,
        status: subscription.status,
        currentPeriodEnd: subscription.current_period_end,
        customerPortalUrl: portalSession.url
      }
    });
  } catch (error: any) {
    console.error("Error handling successful payment:", error);
    res.status(500).json({
      success: false,
      error: error.message || "An error occurred while processing the payment"
    });
  }
}); 