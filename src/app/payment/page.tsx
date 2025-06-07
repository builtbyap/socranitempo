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
import { getStripe } from "@/lib/stripe";

// Define subscription plans
const SUBSCRIPTION_PLANS = {
  monthly: {
    id: "price_1RMyDuCyTrsNmVMYSACvTMhw", // $15 monthly
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
    id: "price_1RNNsvCyTrsNmVMYkaaTV7I7", // $50 annual
    name: "Annual",
    price: 50,
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
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);

  useEffect(() => {
    // Get the plan from URL parameters
    const params = new URLSearchParams(window.location.search);
    const plan = params.get('plan');
    if (plan && (plan === 'monthly' || plan === 'annual')) {
      setSelectedPlan(plan);
    }

    async function fetchUserData() {
      try {
        setLoading(true);
        setError(null);

        // Get current user
        const currentUser = auth.currentUser;
        if (!currentUser) {
          console.log('No current user found, redirecting to sign in');
          router.push("/sign-in");
          return;
        }

        console.log('Fetching data for user:', currentUser.uid);
        setUser(currentUser);

        // Fetch subscription status
        const { subscription: subData, error: subError } = await getSubscriptionStatus(currentUser.uid);
        
        if (subError) {
          console.error("Subscription status error:", subError);
          // Handle specific error cases
          if (subError === 'No user ID provided') {
            setError("User ID is missing. Please try signing in again.");
          } else if (subError === 'Failed to create customer record') {
            setError("Unable to create your account. Please try again or contact support.");
          } else if (subError === 'Invalid subscription data') {
            setError("Your subscription data is invalid. Please contact support.");
          } else if (subError === 'Subscription expired') {
            setError("Your subscription has expired. Please renew to continue.");
          } else {
            setError("Failed to verify subscription status. Please try again.");
          }
          return;
        }

        if (!subData) {
          console.log("No subscription data found for user:", currentUser.uid);
          setSubscription(null);
          return;
        }

        // Check if subscription is valid
        if (subData.isExpired) {
          console.log("Subscription expired for user:", currentUser.uid);
          setSubscription(null);
          setError("Your subscription has expired. Please renew to continue.");
          return;
        }

        console.log("Setting subscription data:", subData);
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

  const isSubscribed = subscription?.status === "active" && !subscription?.isExpired;
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

      // Get Stripe instance first
      const stripe = await getStripe();
      if (!stripe) {
        throw new Error('Failed to initialize Stripe. Please check your publishable key configuration.');
      }

      const { success, sessionId, error } = await createCheckoutSession(priceId);

      if (!success || !sessionId) {
        throw new Error(error?.toString() || "Failed to create checkout session");
      }

      // Redirect to Stripe Checkout
      const { error: stripeError } = await stripe.redirectToCheckout({
        sessionId
      });

      if (stripeError) {
        throw new Error(stripeError.message);
      }
    } catch (err: any) {
      console.error("Payment error:", err);
      setError(err.message || "An error occurred during payment processing");
    } finally {
      setProcessingPayment(false);
    }
  };

  const handleManageSubscription = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/create-portal-session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const { url, error } = await response.json();
      if (error) {
        throw new Error(error);
      }

      window.location.href = url;
    } catch (error) {
      console.error('Error:', error);
      setError('Failed to open subscription management portal');
    } finally {
      setLoading(false);
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
          <>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-8">
              <div className="flex items-center gap-3 mb-2">
                <InfoIcon className="text-amber-600" />
                <h2 className="text-xl font-semibold text-amber-800">
                  Subscription Required
                </h2>
              </div>
              <p className="text-amber-700">
                Please choose a subscription plan to continue.
              </p>
            </div>

            <div className="grid md:grid-cols-2 gap-8">
              {Object.entries(SUBSCRIPTION_PLANS).map(([key, plan]) => (
                <Card 
                  key={key} 
                  className={`flex flex-col ${
                    selectedPlan === key ? 'ring-2 ring-blue-500' : ''
                  }`}
                >
                  <CardHeader>
                    <CardTitle>{plan.name}</CardTitle>
                    <CardDescription>{plan.description}</CardDescription>
                  </CardHeader>
                  <CardContent className="flex-grow">
                    <div className="text-3xl font-bold mb-4">
                      ${plan.price}
                      <span className="text-base font-normal text-muted-foreground">
                        /{key === 'monthly' ? 'month' : 'year'}
                      </span>
                    </div>
                    <ul className="space-y-2">
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
                      disabled={processingPayment}
                    >
                      {processingPayment ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : (
                        `Subscribe to ${plan.name}`
                      )}
                    </Button>
                  </CardFooter>
                </Card>
              ))}
            </div>
          </>
        )}
      </div>
    </main>
  );
}
