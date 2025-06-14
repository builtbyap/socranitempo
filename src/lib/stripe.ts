import { functions } from "@/lib/firebase";
import { httpsCallable } from "firebase/functions";
import Stripe from 'stripe';

// Initialize Stripe with the secret key
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-05-28.basil',
});

// Export a singleton instance of Stripe
export const getStripe = () => stripe;

// Function to create a payment intent
export const createPaymentIntent = async (amount: number, currency: string, description: string, customerEmail: string, subscriptionType: string) => {
  const createPaymentIntentFn = httpsCallable(functions, 'createPaymentIntent');
  const { data } = await createPaymentIntentFn({
    amount,
    currency,
    description,
    customerEmail,
    subscriptionType,
  });
  return data;
};

// Function to create a checkout session
export const createCheckoutSession = async (priceId: string, successUrl: string, cancelUrl: string) => {
  const createCheckoutSessionFn = httpsCallable(functions, 'createCheckoutSession');
  const { data } = await createCheckoutSessionFn({
    priceId,
    successUrl,
    cancelUrl,
  });
  return data;
};

// Function to verify payment status
export const verifyPaymentStatus = async (paymentIntentId: string, clientSecret: string, userId: string) => {
  const verifyPaymentStatusFn = httpsCallable(functions, 'verifyPaymentStatus');
  const { data } = await verifyPaymentStatusFn({
    paymentIntentId,
    clientSecret,
    userId,
  });
  return data;
};
