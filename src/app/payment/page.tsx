"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@supabase/supabase-js";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { CheckIcon, InfoIcon, Loader2 } from "lucide-react";
import Link from "next/link";
import { createCheckoutSession } from "@/lib/stripe";

// Create a Supabase client for the browser
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

export default function PaymentPage() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [userData, setUserData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [processingPayment, setProcessingPayment] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchUserData() {
      try {
        setLoading(true);

        // Get current user
        const {
          data: { user },
        } = await supabase.auth.getUser();

        if (!user) {
          router.push("/sign-in");
          return;
        }

        setUser(user);

        // Fetch user subscription data
        const { data: userData } = await supabase
          .from("users")
          .select(
            "subscription_status, subscription_type, subscription_end_date",
          )
          .eq("user_id", user.id)
          .single();

        setUserData(userData);
      } catch (error) {
        console.error("Error fetching user data:", error);
        setError("Failed to load user data. Please try again.");
      } finally {
        setLoading(false);
      }
    }

    fetchUserData();
  }, [router]);

  const isSubscribed = userData?.subscription_status === "active";
  const subscriptionType = userData?.subscription_type;
  const subscriptionEndDate = userData?.subscription_end_date
    ? new Date(userData.subscription_end_date).toLocaleDateString()
    : null;

  const handleSubscription = async (type: string, price: number) => {
    try {
      setProcessingPayment(true);
      setError(null);

      if (!user) {
        router.push("/sign-in");
        return;
      }

      // Create a Stripe Checkout session
      const { data, error } = await createCheckoutSession({
        price: price * 100, // Convert to cents for Stripe
        subscriptionType: type,
        successUrl: `${window.location.origin}/dashboard?payment=success`,
        cancelUrl: `${window.location.origin}/payment?payment=canceled`,
        customerEmail: user.email,
        userId: user.id,
      });

      if (error || !data) {
        throw new Error(error || "Failed to create checkout session");
      }

      // Redirect to Stripe Checkout
      window.location.href = data.url;
    } catch (err: any) {
      console.error("Payment error:", err);
      setError(err.message || "An error occurred during payment processing");
    } finally {
      setProcessingPayment(false);
    }
  };

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8 flex justify-center items-center min-h-[60vh]">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <main className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">Subscription</h1>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-6 mb-8">
            <div className="flex items-center gap-3 mb-2">
              <InfoIcon className="text-red-600" />
              <h2 className="text-xl font-semibold text-red-800">Error</h2>
            </div>
            <p className="text-red-700 mb-4">{error}</p>
          </div>
        )}

        {isSubscribed ? (
          <div className="bg-green-50 border border-green-200 rounded-lg p-6 mb-8">
            <div className="flex items-center gap-3 mb-2">
              <CheckIcon className="text-green-600" />
              <h2 className="text-xl font-semibold text-green-800">
                Active Subscription
              </h2>
            </div>
            <p className="text-green-700 mb-4">
              You have an active {subscriptionType} subscription that expires on{" "}
              {subscriptionEndDate}.
            </p>
            <Link href="/dashboard">
              <Button>Go to Dashboard</Button>
            </Link>
          </div>
        ) : (
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-8">
            <div className="flex items-center gap-3 mb-2">
              <InfoIcon className="text-amber-600" />
              <h2 className="text-xl font-semibold text-amber-800">
                Subscription Required
              </h2>
            </div>
            <p className="text-amber-700 mb-4">
              You need an active subscription to access the dashboard and all
              features.
            </p>
          </div>
        )}

        <div className="grid md:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Monthly</CardTitle>
              <CardDescription>Perfect for short-term needs</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-2">$15</div>
              <p className="text-muted-foreground">Billed monthly</p>
              <ul className="mt-4 space-y-2">
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Full access to all features</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Priority support</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Cancel anytime</span>
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button
                className="w-full"
                onClick={() => handleSubscription("monthly", 15)}
                disabled={processingPayment}
              >
                {processingPayment ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Processing...
                  </>
                ) : (
                  "Subscribe Monthly"
                )}
              </Button>
            </CardFooter>
          </Card>

          <Card className="border-primary">
            <CardHeader>
              <CardTitle>Annual</CardTitle>
              <CardDescription>Best value for long-term use</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-2">$150</div>
              <p className="text-muted-foreground">
                Billed annually (Save $30)
              </p>
              <ul className="mt-4 space-y-2">
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>All monthly features</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Premium support</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Two months free</span>
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button
                variant="default"
                className="w-full"
                onClick={() => handleSubscription("annual", 150)}
                disabled={processingPayment}
              >
                {processingPayment ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Processing...
                  </>
                ) : (
                  "Subscribe Annually"
                )}
              </Button>
            </CardFooter>
          </Card>
        </div>
      </div>
    </main>
  );
}
