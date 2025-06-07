import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { corsMiddleware } from '../lib/cors';

admin.initializeApp();

// Create a customer in Stripe
export const createCustomer = functions.https.onRequest(async (req, res) => {
  // Apply CORS middleware
  return corsMiddleware(req, res, async () => {
    try {
      const { userId, email } = req.body;

      if (!userId || !email) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      // Create a customer in Stripe
      const customer = await admin.firestore()
        .collection('customers')
        .doc(userId)
        .set({
          email,
          created: admin.firestore.FieldValue.serverTimestamp(),
          stripeCustomerId: null, // This will be set by the Stripe extension
        });

      res.status(200).json({ success: true });
    } catch (error) {
      console.error('Error creating customer:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });
});

// Get customer ID from Stripe
export const getCustomerId = functions.https.onRequest(async (req, res) => {
  // Apply CORS middleware
  return corsMiddleware(req, res, async () => {
    try {
      const userId = req.query.userId;

      if (!userId) {
        res.status(400).json({ error: 'Missing userId' });
        return;
      }

      const customerDoc = await admin.firestore()
        .collection('customers')
        .doc(userId as string)
        .get();

      if (!customerDoc.exists) {
        res.status(404).json({ error: 'Customer not found' });
        return;
      }

      const customerData = customerDoc.data();
      res.status(200).json({ customerId: customerData?.stripeCustomerId });
    } catch (error) {
      console.error('Error getting customer ID:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });
}); 