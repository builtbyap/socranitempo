import { createClient as createSupabaseClient } from "@supabase/supabase-js";
// import { getSubscriptionStatus } from "@/lib/firebase";

export const createClient = async () => {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
};

export const checkSubscriptionStatus = async (userId: string) => {
  try {
    // Get subscription status from Firebase Stripe extension
    const { subscription, error } = await getSubscriptionStatus(userId);

    if (error || !subscription) {
      console.error("Error checking subscription:", error);
      return { isSubscribed: false };
    }

    // Check if subscription is active and not expired
    const isActive = subscription.status === "active";
    const isExpired = subscription.currentPeriodEnd
      ? new Date(subscription.currentPeriodEnd) < new Date()
      : true;

    return {
      isSubscribed: isActive && !isExpired,
      subscriptionData: subscription,
    };
  } catch (error) {
    console.error("Error checking subscription:", error);
    return { isSubscribed: false };
  }
};
