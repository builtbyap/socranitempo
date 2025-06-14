import { functions } from "@/lib/firebase";
import { httpsCallable } from "firebase/functions";
import Stripe from 'stripe';

// Initialize Stripe with the secret key
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

// Export a singleton instance of Stripe
export const getStripe = () => stripe;

// Function to create a payment intent
export async function createPaymentIntent({
  amount,
  currency = "usd",
  description,
  customerEmail,
  subscriptionType,
}: {
  amount: number;
  currency?: string;
  description?: string;
  customerEmail?: string;
  subscriptionType?: string;
}) {
  try {
    const createPaymentIntent = httpsCallable(functions, 'createPaymentIntent');
    const result = await createPaymentIntent({
      amount,
      currency,
      description,
      customerEmail,
      subscriptionType,
    });

    return { data: result.data, error: null };
  } catch (error: any) {
    console.error("Error creating payment intent:", error);
    return { data: null, error: error.message };
  }
}

// Function to create a checkout session
export async function createCheckoutSession({
  priceId,
  successUrl,
  cancelUrl,
}: {
  priceId: string;
  successUrl: string;
  cancelUrl: string;
}) {
  try {
    const createCheckoutSession = httpsCallable(functions, 'createCheckoutSession');
    const result = await createCheckoutSession({
      priceId,
      successUrl,
      cancelUrl,
    });

    return { data: result.data, error: null };
  } catch (error: any) {
    console.error("Error creating checkout session:", error);
    return { data: null, error: error.message };
  }
}

// Function to verify payment status
export async function verifyPaymentStatus({
  paymentIntentId,
  clientSecret,
  userId,
}: {
  paymentIntentId: string;
  clientSecret: string;
  userId: string;
}) {
  try {
    const verifyPaymentStatus = httpsCallable(functions, 'verifyPaymentStatus');
    const result = await verifyPaymentStatus({
      paymentIntentId,
      clientSecret,
      userId,
    });

    return { data: result.data, error: null };
  } catch (error: any) {
    console.error("Error verifying payment status:", error);
    return { data: null, error: error.message };
  }
}
