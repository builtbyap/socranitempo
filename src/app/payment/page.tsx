"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
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
import { createCheckoutSession, getCustomerPortalUrl, getSubscriptionStatus, auth } from "@/lib/firebase";

// Define subscription plans
const SUBSCRIPTION_PLANS = {
  monthly: {
    id: "price_1RMyDuCyTrsNmVMYSACvTMhw", // Replace with your actual Stripe price ID
    name: "Monthly",
    price: 15,
    description: "Perfect for short-term needs",
    features: [
      "Full access to all features",
      "Priority support",
      "Monthly updates",
    ],
  },
  annual: {
    id: "price_1RNNsvCyTrsNmVMYkaaTV7I7", // Replace with your actual Stripe price ID
    name: "Annual",
    price: 150,
    description: "Best value for long-term use",
    features: [
      "Full access to all features",
      "Priority support",
      "Monthly updates",
      "2 months free",
      "Early access to new features",
    ],
  },
};

export default function PaymentPage() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [subscription, setSubscription] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [processingPayment, setProcessingPayment] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchUserData() {
      try {
        setLoading(true);

        // Get current user
        const currentUser = auth.currentUser;
        if (!currentUser) {
          router.push("/sign-in");
          return;
        }

        setUser(currentUser);

        // Fetch subscription status
        const { subscription: subData } = await getSubscriptionStatus(currentUser.uid);
        setSubscription(subData);
      } catch (error) {
        console.error("Error fetching user data:", error);
        setError("Failed to load user data. Please try again.");
      } finally {
        setLoading(false);
      }
    }

    fetchUserData();
  }, [router]);

  const isSubscribed = subscription?.status === "active";
  const subscriptionEndDate = subscription?.currentPeriodEnd
    ? new Date(subscription.currentPeriodEnd).toLocaleDateString()
    : null;

  const handleSubscribe = async (priceId: string) => {
    try {
      setProcessingPayment(true);
      setError(null);

      if (!user) {
        router.push("/sign-in");
        return;
      }

      const response = await fetch("/api/create-checkout-session", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ priceId }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to create checkout session");
      }

      // Redirect to Stripe Checkout
      window.location.href = `https://checkout.stripe.com/pay/${data.sessionId}`;
    } catch (err: any) {
      console.error("Payment error:", err);
      setError(err.message || "An error occurred during payment processing");
    } finally {
      setProcessingPayment(false);
    }
  };

  const handleManageSubscription = async () => {
    try {
      setProcessingPayment(true);
      setError(null);

      const { success, url, error } = await getCustomerPortalUrl();

      if (!success || !url) {
        throw new Error(error?.toString() || "Failed to get customer portal URL");
      }

      // Redirect to Stripe Customer Portal
      window.location.href = url;
    } catch (err: any) {
      console.error("Error:", err);
      setError(err.message || "An error occurred while accessing the customer portal");
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
              Your subscription is active and will renew on {subscriptionEndDate}.
            </p>
            <div className="flex gap-4">
              <Link href="/dashboard">
                <Button>Go to Dashboard</Button>
              </Link>
              <Button
                variant="outline"
                onClick={handleManageSubscription}
                disabled={processingPayment}
              >
                {processingPayment ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  "Manage Subscription"
                )}
              </Button>
            </div>
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
          {Object.entries(SUBSCRIPTION_PLANS).map(([key, plan]) => (
            <Card key={key}>
              <CardHeader>
                <CardTitle>{plan.name}</CardTitle>
                <CardDescription>{plan.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold mb-2">${plan.price}</div>
                <p className="text-muted-foreground">
                  {key === "monthly" ? "Billed monthly" : "Billed annually"}
                </p>
                <ul className="mt-4 space-y-2">
                  {plan.features.map((feature, index) => (
                    <li key={index} className="flex items-center gap-2">
                      <CheckIcon className="h-4 w-4 text-green-500" />
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
              </CardContent>
              <CardFooter>
                <Button
                  className="w-full"
                  onClick={() => handleSubscribe(plan.id)}
                  disabled={processingPayment || isSubscribed}
                >
                  {processingPayment ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : isSubscribed ? (
                    "Current Plan"
                  ) : (
                    "Subscribe"
                  )}
                </Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      </div>
    </main>
  );
}
