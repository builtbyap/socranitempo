import { createClient } from "@supabase/supabase-js";
import { loadStripe, Stripe } from '@stripe/stripe-js';

// Create a Supabase client for the browser
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

// Initialize Stripe with your publishable key
const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || '');

export const getStripe = async (): Promise<Stripe | null> => {
  if (!stripePromise) {
    throw new Error('Stripe failed to initialize. Please check your publishable key.');
  }
  return stripePromise;
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
