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
        const { data: { session } } = await supabase.auth.getSession();
        
        if (!session) {
          router.push("/sign-in");
          return;
        }

        const { data: user } = await supabase
          .from("subs")
          .select("subscription_status, subscription_end_date")
          .eq("id", session.user.id)
          .single();

        const isSubscribed = 
          user?.subscription_status === "active" && 
          user?.subscription_end_date && 
          new Date(user.subscription_end_date) > new Date();

        if (!isSubscribed) {
          toast.error("Please subscribe to access the dashboard");
          router.push("/pricing");
          return;
        }

        setIsLoading(false);
      } catch (error) {
        console.error("Error checking subscription:", error);
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