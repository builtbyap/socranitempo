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

  useEffect(() => {
    let isMounted = true;
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!isMounted) return;
      if (!user) {
        router.replace("/sign-in");
        return;
      }
      try {
        const customerRef = doc(db, "customers", user.uid);
        const customerDoc = await getDoc(customerRef);
        if (!customerDoc.exists()) {
          router.replace("/pricing");
          return;
        }
        const customerData = customerDoc.data();
        let subscriptionStatus = null;
        let subscriptionData = null;
        const subscriptionsSnapshot = await getDocs(collection(customerRef, 'subscriptions'));
        if (!subscriptionsSnapshot.empty) {
          const latestSubscription = subscriptionsSnapshot.docs[0].data();
          subscriptionData = latestSubscription;
          subscriptionStatus = latestSubscription.status;
        }
        if (!subscriptionStatus) {
          if (customerData.subscription) {
            subscriptionData = customerData.subscription;
            subscriptionStatus = subscriptionData.status || subscriptionData.subscriptionStatus;
          } else if (customerData.subscriptionStatus) {
            subscriptionStatus = customerData.subscriptionStatus;
          } else if (customerData.status) {
            subscriptionStatus = customerData.status;
          }
        }
        if (!subscriptionStatus) {
          router.replace("/pricing");
          return;
        }
        const normalizedStatus = subscriptionStatus.toLowerCase().trim();
        const isActive = normalizedStatus === "active";
        const isExpired = subscriptionData?.currentPeriodEnd 
          ? new Date(subscriptionData.currentPeriodEnd.toDate()) < new Date()
          : false;
        if (!isActive || isExpired) {
          router.replace("/pricing");
          return;
        }
        setIsLoading(false);
      } catch (err) {
        setError("Error checking subscription status");
        router.replace("/pricing");
      }
    });
    return () => {
      isMounted = false;
      unsubscribe();
    };
  }, [router]);

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
