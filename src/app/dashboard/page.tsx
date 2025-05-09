"use client";

export const dynamic = 'force-dynamic';

import { useEffect, useState } from "react";
import { createClient } from "../../../supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

interface SubscriptionInfo {
  status: string;
  endDate: string;
}

export default function DashboardPage() {
  const [subscriptionInfo, setSubscriptionInfo] = useState<SubscriptionInfo | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const supabase = createClient();

  useEffect(() => {
    const fetchSubscriptionInfo = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        
        if (!session) {
          router.push("/sign-in");
          return;
        }

        const { data: user } = await supabase
          .from("users")
          .select("subscription_status, subscription_end_date")
          .eq("id", session.user.id)
          .single();

        if (user) {
          setSubscriptionInfo({
            status: user.subscription_status,
            endDate: user.subscription_end_date,
          });
        }
      } catch (error) {
        console.error("Error fetching subscription info:", error);
        toast.error("Failed to load subscription information");
      } finally {
        setIsLoading(false);
      }
    };

    fetchSubscriptionInfo();
  }, [router, supabase]);

  const handleManageSubscription = () => {
    // Redirect to Stripe customer portal
    window.location.href = "https://billing.stripe.com/p/login/test_28o5kO0Fw0Fw0Fw0Fw";
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground">Welcome to your dashboard</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Subscription Status</CardTitle>
          <CardDescription>Your current subscription details</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div>
              <p className="text-sm font-medium">Status</p>
              <p className="text-2xl font-bold capitalize">
                {subscriptionInfo?.status || "No subscription"}
              </p>
            </div>
            
            {subscriptionInfo?.endDate && (
              <div>
                <p className="text-sm font-medium">Valid Until</p>
                <p className="text-lg">
                  {new Date(subscriptionInfo.endDate).toLocaleDateString()}
                </p>
              </div>
            )}

            <Button 
              onClick={handleManageSubscription}
              className="mt-4"
            >
              Manage Subscription
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
