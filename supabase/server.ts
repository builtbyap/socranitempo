import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export const createClient = async () => {
  const cookieStore = cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll().map(({ name, value }) => ({
            name,
            value,
          }));
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        },
      },
    },
  );
};

export const checkSubscriptionStatus = async (userId: string) => {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("users")
    .select("subscription_status, subscription_end_date")
    .eq("user_id", userId)
    .single();

  if (error || !data) {
    return { isSubscribed: false };
  }

  // Check if subscription is active and not expired
  const isActive = data.subscription_status === "active";
  const isExpired = data.subscription_end_date
    ? new Date(data.subscription_end_date) < new Date()
    : true;

  return {
    isSubscribed: isActive && !isExpired,
    subscriptionData: data,
  };
};
