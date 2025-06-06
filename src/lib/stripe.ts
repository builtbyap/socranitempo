import { createClient } from "@supabase/supabase-js";
import { loadStripe, Stripe } from '@stripe/stripe-js';

// Create a Supabase client for the browser
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

// Initialize Stripe with your publishable key
let stripePromise: Promise<Stripe | null> | null = null;

export const getStripe = async (): Promise<Stripe | null> => {
  if (!stripePromise) {
    const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
    
    // Debug log to check the publishable key
    console.log('Stripe publishable key:', publishableKey ? 'Key is present' : 'Key is missing');
    
    if (!publishableKey) {
      console.error('Stripe publishable key is not configured. Please add NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY to your .env.local file');
      return null;
    }

    // Validate the publishable key format
    if (!publishableKey.startsWith('pk_test_') && !publishableKey.startsWith('pk_live_')) {
      console.error('Invalid Stripe publishable key format. Key should start with pk_test_ or pk_live_');
      return null;
    }

    try {
      stripePromise = loadStripe(publishableKey);
    } catch (error) {
      console.error('Error loading Stripe:', error);
      return null;
    }
  }

  try {
    const stripe = await stripePromise;
    if (!stripe) {
      throw new Error('Failed to initialize Stripe');
    }
    return stripe;
  } catch (error) {
    console.error('Error initializing Stripe:', error);
    return null;
  }
};

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
    const { data, error } = await supabase.functions.invoke(
      "supabase-functions-create_payment_intent",
      {
        body: {
          amount,
          currency,
          description,
          customer_email: customerEmail,
          subscription_type: subscriptionType,
        },
      },
    );

    if (error) throw new Error(error.message);
    return { data, error: null };
  } catch (error: any) {
    console.error("Error creating payment intent:", error);
    return { data: null, error: error.message };
  }
}

// Function to create a checkout session
export async function createCheckoutSession({
  price,
  quantity = 1,
  subscriptionType,
  successUrl,
  cancelUrl,
  customerEmail,
  userId,
}: {
  price: number;
  quantity?: number;
  subscriptionType: string;
  successUrl: string;
  cancelUrl: string;
  customerEmail?: string;
  userId?: string;
}) {
  try {
    const { data, error } = await supabase.functions.invoke(
      "supabase-functions-create_checkout_session",
      {
        body: {
          price,
          quantity,
          subscription_type: subscriptionType,
          success_url: successUrl,
          cancel_url: cancelUrl,
          customer_email: customerEmail,
          user_id: userId,
        },
      },
    );

    if (error) throw new Error(error.message);
    return { data, error: null };
  } catch (error: any) {
    console.error("Error creating checkout session:", error);
    return { data: null, error: error.message };
  }
}

// Function to update user subscription in the database
export async function updateUserSubscription({
  userId,
  subscriptionType,
  subscriptionStatus = "active",
  durationMonths = 1,
}: {
  userId: string;
  subscriptionType: string;
  subscriptionStatus?: string;
  durationMonths?: number;
}) {
  try {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setMonth(endDate.getMonth() + durationMonths);

    const { error } = await supabase
      .from("users")
      .update({
        subscription_type: subscriptionType,
        subscription_status: subscriptionStatus,
        subscription_start_date: startDate.toISOString(),
        subscription_end_date: endDate.toISOString(),
      })
      .eq("user_id", userId);

    if (error) throw new Error(error.message);
    return { success: true, error: null };
  } catch (error: any) {
    console.error("Error updating user subscription:", error);
    return { success: false, error: error.message };
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
    const { data, error } = await supabase.functions.invoke(
      "supabase-functions-verify_payment_status",
      {
        body: {
          payment_intent_id: paymentIntentId,
          client_secret: clientSecret,
          user_id: userId,
        },
      },
    );

    if (error) throw new Error(error.message);
    return { data, error: null };
  } catch (error: any) {
    console.error("Error verifying payment status:", error);
    return { data: null, error: error.message };
  }
}
