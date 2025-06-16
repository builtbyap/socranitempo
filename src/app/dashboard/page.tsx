"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import DashboardNavbar from "@/components/dashboard-navbar";
import DashboardTabs from "@/components/dashboard/tabs";
import { InfoIcon } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { doc, getDoc, collection, getDocs } from "firebase/firestore";
import { onAuthStateChanged } from "firebase/auth";

export default function Dashboard() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");
  const [isRedirecting, setIsRedirecting] = useState(false);

  useEffect(() => {
    let isMounted = true;
    let redirectTimeout: NodeJS.Timeout;

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!isMounted) return;

      if (!user) {
        console.log("No user found, redirecting to sign-in");
        setIsRedirecting(true);
        redirectTimeout = setTimeout(() => {
          if (isMounted) {
            router.push("/sign-in");
          }
        }, 500);
        return;
      }

      try {
        console.log("Checking subscription for user:", user.uid);
        const customerRef = doc(db, "customers", user.uid);
        const customerDoc = await getDoc(customerRef);
        
        if (!isMounted) return;

        if (!customerDoc.exists()) {
          console.log("No customer document found for user:", user.uid);
          setIsRedirecting(true);
          redirectTimeout = setTimeout(() => {
            if (isMounted) {
              router.push("/pricing");
            }
          }, 500);
          return;
        }

        const customerData = customerDoc.data();
        console.log("Raw customer data:", JSON.stringify(customerData, null, 2));

        if (!customerData) {
          console.log("Customer data is null or undefined");
          setIsRedirecting(true);
          redirectTimeout = setTimeout(() => {
            if (isMounted) {
              router.push("/pricing");
            }
          }, 500);
          return;
        }

        // Check for subscription data in various possible locations
        let subscriptionStatus = null;
        let subscriptionData = null;

        // First, try to find the subscription data in the subscriptions subcollection
        const subscriptionsSnapshot = await getDocs(collection(customerRef, 'subscriptions'));
        if (!isMounted) return;

        if (!subscriptionsSnapshot.empty) {
          const latestSubscription = subscriptionsSnapshot.docs[0].data();
          subscriptionData = latestSubscription;
          subscriptionStatus = latestSubscription.status;
          console.log("Found subscription in subcollection:", subscriptionStatus);
        }

        // If no subscription found in subcollection, check the root document
        if (!subscriptionStatus) {
          if (customerData.subscription) {
            subscriptionData = customerData.subscription;
            subscriptionStatus = subscriptionData.status || subscriptionData.subscriptionStatus;
            console.log("Found subscription in root:", subscriptionStatus);
          } else if (customerData.subscriptionStatus) {
            subscriptionStatus = customerData.subscriptionStatus;
            console.log("Found subscriptionStatus in root:", subscriptionStatus);
          } else if (customerData.status) {
            subscriptionStatus = customerData.status;
            console.log("Found status in root:", subscriptionStatus);
          }
        }

        if (!isMounted) return;

        if (!subscriptionStatus) {
          console.log("No valid subscription status found in customer data");
          console.log("Available fields:", Object.keys(customerData));
          if (subscriptionData) {
            console.log("Subscription object fields:", Object.keys(subscriptionData));
          }
          setIsRedirecting(true);
          redirectTimeout = setTimeout(() => {
            if (isMounted) {
              router.push("/pricing");
            }
          }, 500);
          return;
        }

        // Normalize the status to lowercase for comparison
        const normalizedStatus = subscriptionStatus.toLowerCase().trim();
        console.log("Normalized subscription status:", normalizedStatus);
        
        // Check if subscription is active and not expired
        const isActive = normalizedStatus === "active";
        const isExpired = subscriptionData?.currentPeriodEnd 
          ? new Date(subscriptionData.currentPeriodEnd.toDate()) < new Date()
          : false;

        if (!isMounted) return;

        if (!isActive || isExpired) {
          console.log("Subscription not active or expired. Status:", normalizedStatus, "Expired:", isExpired);
          setIsRedirecting(true);
          redirectTimeout = setTimeout(() => {
            if (isMounted) {
              router.push("/pricing");
            }
          }, 500);
          return;
        }

        console.log("Subscription is active and valid, allowing access to dashboard");
        setIsLoading(false);
      } catch (error) {
        if (!isMounted) return;
        
        console.error("Error checking subscription:", error);
        if (error instanceof Error) {
          console.error("Error details:", error.message);
          console.error("Error stack:", error.stack);
        }
        setError("Error checking subscription status");
        setIsRedirecting(true);
        redirectTimeout = setTimeout(() => {
          if (isMounted) {
            router.push("/pricing");
          }
        }, 500);
      }
    });

    return () => {
      isMounted = false;
      if (redirectTimeout) {
        clearTimeout(redirectTimeout);
      }
      unsubscribe();
    };
  }, [router]);

  if (isRedirecting) {
    return (
      <div className="container flex h-screen w-screen flex-col items-center justify-center">
        <div className="text-lg">Redirecting...</div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="container flex h-screen w-screen flex-col items-center justify-center">
        <div className="text-lg">Loading dashboard...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container flex h-screen w-screen flex-col items-center justify-center">
        <div className="text-red-500">{error}</div>
      </div>
    );
  }

  return (
    <>
      <DashboardNavbar />
      <main className="w-full">
        <div className="container mx-auto px-4 py-8 flex flex-col gap-8">
          {/* Header Section */}
          <header className="flex flex-col gap-4">
            <h1 className="text-3xl font-bold">Dashboard</h1>
            <div className="bg-secondary/50 text-sm p-3 px-4 rounded-lg text-muted-foreground flex gap-2 items-center">
              <InfoIcon size="14" />
              <span>
                Welcome to your dashboard
              </span>
            </div>
          </header>

          {/* Dashboard Tabs Section */}
          <section className="bg-card rounded-xl p-6 border shadow-sm">
            <DashboardTabs />
          </section>
        </div>
      </main>
    </>
  );
}
