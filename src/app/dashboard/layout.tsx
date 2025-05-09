"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const checkSubscription = async () => {
      try {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) {
          console.error("Error getting session:", sessionError);
          toast.error("Error checking authentication status");
          router.push("/sign-in");
          return;
        }
        
        if (!session) {
          console.log("No session found, redirecting to sign-in");
          router.push("/sign-in");
          return;
        }

        console.log("Checking subscription for user:", session.user.id);

        const { data: user, error: subscriptionError } = await supabase
          .from("subs")
          .select("subscription_status, subscription_end_date")
          .eq("id", session.user.id)
          .single();

        if (subscriptionError) {
          console.error("Error fetching subscription:", subscriptionError);
          toast.error("Error checking subscription status");
          router.push("/pricing");
          return;
        }

        console.log("Subscription data:", user);

        if (!user) {
          console.log("No subscription found for user");
          toast.error("Please subscribe to access the dashboard");
          router.push("/pricing");
          return;
        }

        // Check if subscription is active
        const isSubscribed = user.subscription_status === "active";
        console.log("Is subscribed:", isSubscribed);

        if (!isSubscribed) {
          console.log("No active subscription, redirecting to pricing");
          toast.error("Please subscribe to access the dashboard");
          router.push("/pricing");
          return;
        }

        console.log("Access granted to dashboard");
        setIsLoading(false);
      } catch (error) {
        console.error("Error in subscription check:", error);
        toast.error("Error checking subscription status");
        router.push("/pricing");
      }
    };

    checkSubscription();
  }, [router]);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
          <p className="mt-4 text-muted-foreground">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <main className="container mx-auto px-4 py-8">
        {children}
      </main>
    </div>
  );
} 