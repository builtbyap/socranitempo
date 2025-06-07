"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { onAuthStateChanged } from "firebase/auth";
import { auth, db } from "@/lib/firebase";
import { doc, onSnapshot, getDoc } from "firebase/firestore";
import { handleSuccessfulPayment } from "@/lib/firebase/functions";

export default function SuccessPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const [success, setSuccess] = useState(false);
  const maxRetries = 3;

  useEffect(() => {
    let authUnsubscribe: (() => void) | undefined;
    let subscriptionUnsubscribe: (() => void) | undefined;
    let timeoutId: NodeJS.Timeout;

    const processPayment = async (uid: string) => {
      try {
        const sessionId = searchParams.get("session_id");
        if (!sessionId) {
          throw new Error("No session ID found in URL");
        }

        console.log("Processing payment for session:", sessionId);

        // Call the Firebase function to handle the payment
        const result = await handleSuccessfulPayment({ sessionId });
        console.log("Payment processing result:", result);

        if (!result.success) {
          throw new Error("Payment processing failed");
        }

        // Get the customer document
        const customerRef = doc(db, "customers", uid);
        const customerDoc = await getDoc(customerRef);

        if (!customerDoc.exists()) {
          throw new Error("Customer document not found");
        }

        const customerData = customerDoc.data();
        const subscriptionId = customerData.stripeSubscriptionId;

        if (!subscriptionId) {
          throw new Error("No subscription ID found in customer document");
        }

        console.log("Found subscription ID:", subscriptionId);

        // Set up listener for subscription status
        const subscriptionRef = doc(db, "customers", uid, "subscriptions", subscriptionId);
        subscriptionUnsubscribe = onSnapshot(subscriptionRef, (doc) => {
          if (doc.exists()) {
            const data = doc.data();
            console.log("Subscription status updated:", data.status);
            
            if (data.status === "active") {
              setSuccess(true);
              setLoading(false);
              // Redirect to dashboard after a short delay
              timeoutId = setTimeout(() => {
                router.push("/dashboard");
              }, 2000);
            }
          }
        }, (error) => {
          console.error("Error listening to subscription:", error);
          setError("Error checking subscription status");
          setLoading(false);
        });

      } catch (err: any) {
        console.error("Error processing payment:", err);
        setError(err.message || "An error occurred while processing your payment");
        setLoading(false);
      }
    };

    // Set up auth state listener with retry mechanism
    authUnsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        console.log("User authenticated:", user.uid);
        await processPayment(user.uid);
      } else if (retryCount < maxRetries) {
        console.log(`Retrying auth check (${retryCount + 1}/${maxRetries})...`);
        setRetryCount(prev => prev + 1);
        // Wait for 1 second before retrying
        await new Promise(resolve => setTimeout(resolve, 1000));
      } else {
        console.error("Max retries reached, user not authenticated");
        setError("Please sign in to complete your payment");
        setLoading(false);
      }
    });

    // Cleanup function
    return () => {
      if (authUnsubscribe) authUnsubscribe();
      if (subscriptionUnsubscribe) subscriptionUnsubscribe();
      if (timeoutId) clearTimeout(timeoutId);
    };
  }, [searchParams, router, retryCount]);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Card className="w-[350px]">
          <CardHeader>
            <CardTitle className="text-center">Processing Payment</CardTitle>
            <CardDescription className="text-center">
              Please wait while we confirm your subscription...
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </CardContent>
        </Card>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Card className="w-[350px]">
          <CardHeader>
            <CardTitle className="text-center text-destructive">Error</CardTitle>
            <CardDescription className="text-center">
              {error}
            </CardDescription>
          </CardHeader>
          <CardFooter className="flex justify-center">
            {error === "Please sign in to complete your payment" ? (
              <Button onClick={() => router.push("/signin")}>
                Sign In
              </Button>
            ) : (
              <Button onClick={() => router.push("/payment")}>
                Return to Payment
              </Button>
            )}
          </CardFooter>
        </Card>
      </div>
    );
  }

  if (success) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Card className="w-[350px]">
          <CardHeader>
            <CardTitle className="text-center text-green-600">Payment Successful!</CardTitle>
            <CardDescription className="text-center">
              Your subscription has been activated. Redirecting to dashboard...
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </CardContent>
        </Card>
      </div>
    );
  }

  return null;
} 