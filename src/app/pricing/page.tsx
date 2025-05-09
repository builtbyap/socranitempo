"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Check } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { toast } from "sonner";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { supabase } from "@/lib/supabase";

export default function PricingPage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!auth) return; // Guard against undefined auth

    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        setUserId(user.uid);
      } else {
        setUserId(null);
      }
    });

    return () => unsubscribe();
  }, []);

  const handleSubscribe = async () => {
    try {
      setIsLoading(true);
      
      // Open Stripe checkout in a new tab
      const stripeWindow = window.open(
        "https://buy.stripe.com/test_fZu8wOaxwdki3ArbQdeUU07",
        "_blank"
      );

      if (!stripeWindow) {
        toast.error("Please allow popups for this website");
        return;
      }

      // Check subscription status every 5 seconds
      const checkSubscription = setInterval(async () => {
        try {
          if (!userId) return;

          const { data: { session } } = await supabase.auth.getSession();
          if (!session) return;

          const { data: user } = await supabase
            .from("subs")
            .select("subscription_status")
            .eq("id", session.user.id)
            .single();

          if (user?.subscription_status === "active") {
            clearInterval(checkSubscription);
            toast.success("Subscription successful! Redirecting to dashboard...");
            router.push("/dashboard");
          }
        } catch (error) {
          console.error("Error checking subscription:", error);
        }
      }, 5000);

      // Clear interval after 5 minutes (timeout)
      setTimeout(() => {
        clearInterval(checkSubscription);
      }, 5 * 60 * 1000);

    } catch (error) {
      console.error("Error redirecting to Stripe:", error);
      toast.error("Failed to process subscription. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4 py-8">
      <div className="w-full max-w-4xl">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-4">Choose Your Plan</h1>
          <p className="text-muted-foreground">
            Get access to all premium features with our subscription plan
          </p>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {/* Free Plan */}
          <Card>
            <CardHeader>
              <CardTitle>Free</CardTitle>
              <CardDescription>Basic features for everyone</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-4">$0</div>
              <ul className="space-y-2">
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Basic features
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Limited access
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button variant="outline" className="w-full" disabled>
                Current Plan
              </Button>
            </CardFooter>
          </Card>

          {/* Premium Plan */}
          <Card className="border-primary">
            <CardHeader>
              <CardTitle>Premium</CardTitle>
              <CardDescription>Full access to all features</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-4">$15<span className="text-sm font-normal text-muted-foreground">/month</span></div>
              <ul className="space-y-2">
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Full dashboard access
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Premium features
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Priority support
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Advanced analytics
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button 
                className="w-full" 
                onClick={handleSubscribe}
                disabled={isLoading}
              >
                {isLoading ? "Processing..." : "Subscribe Now"}
              </Button>
            </CardFooter>
          </Card>

          {/* Enterprise Plan */}
          <Card>
            <CardHeader>
              <CardTitle>Enterprise</CardTitle>
              <CardDescription>Custom solutions for businesses</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-4">Custom</div>
              <ul className="space-y-2">
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Everything in Premium
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Custom integrations
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  Dedicated support
                </li>
                <li className="flex items-center">
                  <Check className="h-4 w-4 mr-2 text-green-500" />
                  SLA guarantees
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button variant="outline" className="w-full">
                Contact Sales
              </Button>
            </CardFooter>
          </Card>
        </div>
      </div>
    </div>
  );
}
