"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { CheckCircle2, Loader2 } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { doc, onSnapshot, getDoc } from "firebase/firestore";

function SuccessContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const [success, setSuccess] = useState(false);
  const [subscriptionStatus, setSubscriptionStatus] = useState<string | null>(null);

  useEffect(() => {
    const processPayment = async () => {
      try {
        const sessionId = searchParams.get("session_id");
        if (!sessionId) {
          throw new Error("No session ID found");
        }

        console.log("Processing payment with session ID:", sessionId);

        // Wait for auth state to be ready
        const unsubscribe = onAuthStateChanged(auth, async (user) => {
          if (!user) {
            if (retryCount < 3) {
              console.log(`Auth not ready, retry ${retryCount + 1}/3`);
              // Retry after a short delay
              setTimeout(() => {
                setRetryCount(prev => prev + 1);
              }, 1000);
              return;
            }
            throw new Error("Please sign in to complete your payment");
          }

          console.log("User authenticated:", user.uid);

          try {
            // First, get the customer document to find the subscription ID
            const customerRef = doc(db, "customers", user.uid);
            const customerDoc = await getDoc(customerRef);
            const customerData = customerDoc.data();
            
            if (!customerData?.stripeSubscriptionId) {
              console.error("No subscription ID found in customer document");
              setError("Unable to find subscription details. Please contact support.");
              setLoading(false);
              return;
            }

            const subscriptionId = customerData.stripeSubscriptionId;
            console.log("Found subscription ID:", subscriptionId);

            // Listen for changes to the subscription status
            const subscriptionRef = doc(db, "customers", user.uid, "subscriptions", subscriptionId);
            console.log("Setting up Firestore listener for subscription:", subscriptionId);

            const unsubscribeSnapshot = onSnapshot(subscriptionRef, (doc) => {
              const data = doc.data();
              console.log("Firestore update received:", data);

              if (data) {
                setSubscriptionStatus(data.status || "unknown");
                
                // Check for active subscription
                if (data.status === "active") {
                  console.log("Subscription is active, setting success state");
                  setSuccess(true);
                  // Wait a moment to show the success state
                  setTimeout(() => {
                    console.log("Redirecting to dashboard");
                    router.push("/dashboard?payment=success");
                  }, 2000);
                } else if (data.status === "trialing") {
                  console.log("Subscription is in trial period");
                  setSuccess(true);
                  setTimeout(() => {
                    router.push("/dashboard?payment=success");
                  }, 2000);
                } else if (data.status === "incomplete") {
                  console.log("Subscription is incomplete");
                  setError("Your subscription is still being processed. Please wait a moment.");
                } else if (data.status === "past_due") {
                  console.log("Subscription is past due");
                  setError("There was an issue with your payment. Please check your payment method.");
                } else {
                  console.log("Unknown subscription status:", data.status);
                  setError("Unable to verify subscription status. Please contact support.");
                }
              } else {
                console.log("No subscription data found in Firestore");
                setError("Unable to find your subscription details. Please contact support.");
              }
              setLoading(false);
            }, (error) => {
              console.error("Error listening to subscription status:", error);
              setError("Failed to verify subscription status");
              setLoading(false);
            });

            // Set a timeout to handle cases where the subscription status doesn't update
            setTimeout(() => {
              if (!success && !error) {
                console.log("Timeout reached without subscription status update");
                setError("Payment processing is taking longer than expected. Please check your dashboard or contact support.");
                setLoading(false);
              }
            }, 30000); // 30 second timeout

            // Cleanup subscription
            return () => unsubscribeSnapshot();
          } catch (err: any) {
            console.error("Error processing payment:", err);
            setError(err.message || "An error occurred while processing your payment");
            setLoading(false);
          }
        });

        // Cleanup auth subscription
        return () => unsubscribe();
      } catch (err: any) {
        console.error("Error in payment process:", err);
        setError(err.message || "An error occurred while processing your payment");
        setLoading(false);
      }
    };

    processPayment();
  }, [router, searchParams, retryCount, success]);

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8 flex justify-center items-center min-h-[60vh]">
        <div className="text-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary mx-auto mb-4" />
          <p className="text-lg">Processing your payment...</p>
          {retryCount > 0 && (
            <p className="text-sm text-gray-500 mt-2">
              Verifying your session... (Attempt {retryCount}/3)
            </p>
          )}
          {subscriptionStatus && (
            <p className="text-sm text-gray-500 mt-2">
              Current status: {subscriptionStatus}
            </p>
          )}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Card className="max-w-md mx-auto">
          <CardHeader>
            <CardTitle className="text-red-600">Payment Error</CardTitle>
            <CardDescription>There was a problem processing your payment</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-600">{error}</p>
          </CardContent>
          <CardFooter className="flex flex-col gap-2">
            <Button onClick={() => router.push("/payment")} className="w-full">
              Return to Payment
            </Button>
            {error.includes("sign in") && (
              <Button 
                onClick={() => router.push("/sign-in")} 
                variant="outline" 
                className="w-full"
              >
                Sign In
              </Button>
            )}
          </CardFooter>
        </Card>
      </div>
    );
  }

  if (success) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Card className="max-w-md mx-auto">
          <CardHeader>
            <div className="flex justify-center mb-4">
              <CheckCircle2 className="h-12 w-12 text-green-500" />
            </div>
            <CardTitle className="text-center">Payment Successful!</CardTitle>
            <CardDescription className="text-center">
              Thank you for your subscription
            </CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-center text-sm text-gray-600">
              Your subscription has been activated. You will be redirected to the dashboard shortly.
            </p>
          </CardContent>
          <CardFooter>
            <Button onClick={() => router.push("/dashboard")} className="w-full">
              Go to Dashboard
            </Button>
          </CardFooter>
        </Card>
      </div>
    );
  }

  return null;
}

export default function SuccessPage() {
  return (
    <Suspense fallback={
      <div className="container mx-auto px-4 py-8 flex justify-center items-center min-h-[60vh]">
        <div className="text-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary mx-auto mb-4" />
          <p className="text-lg">Loading...</p>
        </div>
      </div>
    }>
      <SuccessContent />
    </Suspense>
  );
} 