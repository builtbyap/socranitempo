import DashboardNavbar from "@/components/dashboard-navbar";
import DashboardTabs from "@/components/dashboard/tabs";
import { InfoIcon } from "lucide-react";
import { redirect } from "next/navigation";
import { createClient } from "../../../supabase/server";
import { adminDb } from "@/lib/firebase-admin";

export default async function Dashboard() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    console.log("No user found, redirecting to sign-in");
    return redirect("/sign-in");
  }

  console.log("Checking subscription for user:", user.id);
  
  try {
    const customerDoc = await adminDb.collection("customers").doc(user.id).get();
    
    if (!customerDoc.exists) {
      console.log("No customer document found for user:", user.id);
      return redirect("/pricing");
    }

    const customerData = customerDoc.data();
    console.log("Raw customer data:", JSON.stringify(customerData, null, 2));

    if (!customerData) {
      console.log("Customer data is null or undefined");
      return redirect("/pricing");
    }

    // Check for subscription data in various possible locations
    let subscriptionStatus = null;
    let subscriptionData = null;

    // First, try to find the subscription data in the subscriptions subcollection
    const subscriptionsSnapshot = await customerDoc.ref.collection('subscriptions').get();
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

    if (!subscriptionStatus) {
      console.log("No valid subscription status found in customer data");
      console.log("Available fields:", Object.keys(customerData));
      if (subscriptionData) {
        console.log("Subscription object fields:", Object.keys(subscriptionData));
      }
      return redirect("/pricing");
    }

    // Normalize the status to lowercase for comparison
    const normalizedStatus = subscriptionStatus.toLowerCase().trim();
    console.log("Normalized subscription status:", normalizedStatus);
    
    // Check if subscription is active and not expired
    const isActive = normalizedStatus === "active";
    const isExpired = subscriptionData?.currentPeriodEnd 
      ? new Date(subscriptionData.currentPeriodEnd.toDate()) < new Date()
      : false;

    if (!isActive || isExpired) {
      console.log("Subscription not active or expired. Status:", normalizedStatus, "Expired:", isExpired);
      return redirect("/pricing");
    }

    console.log("Subscription is active and valid, allowing access to dashboard");
  } catch (error) {
    console.error("Error checking subscription:", error);
    if (error instanceof Error) {
      console.error("Error details:", error.message);
      console.error("Error stack:", error.stack);
    }
    return redirect("/pricing");
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
                This is a protected page only visible to authenticated users
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
