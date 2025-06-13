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

    // Check direct subscriptionStatus field
    if (typeof customerData.subscriptionStatus === 'string') {
      subscriptionStatus = customerData.subscriptionStatus;
      console.log("Found subscriptionStatus:", subscriptionStatus);
    }
    // Check nested subscription object
    else if (customerData.subscription && typeof customerData.subscription.status === 'string') {
      subscriptionStatus = customerData.subscription.status;
      console.log("Found subscription.status:", subscriptionStatus);
    }
    // Check direct status field
    else if (typeof customerData.status === 'string') {
      subscriptionStatus = customerData.status;
      console.log("Found status:", subscriptionStatus);
    }
    // Check for subscription object with different structure
    else if (customerData.subscription && typeof customerData.subscription === 'object') {
      const subData = customerData.subscription;
      if (typeof subData.subscriptionStatus === 'string') {
        subscriptionStatus = subData.subscriptionStatus;
        console.log("Found subscription.subscriptionStatus:", subscriptionStatus);
      }
    }

    if (!subscriptionStatus) {
      console.log("No valid subscription status found in customer data");
      console.log("Available fields:", Object.keys(customerData));
      return redirect("/pricing");
    }

    // Normalize the status to lowercase for comparison
    const normalizedStatus = subscriptionStatus.toLowerCase().trim();
    console.log("Normalized subscription status:", normalizedStatus);
    
    if (normalizedStatus !== "active") {
      console.log("Subscription not active. Current status:", normalizedStatus);
      return redirect("/pricing");
    }

    console.log("Subscription is active, allowing access to dashboard");
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
