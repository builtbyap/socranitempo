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
    return redirect("/sign-in");
  }

  const customerDoc = await adminDb.collection("customers").doc(user.id).get();
  const customerData = customerDoc.data();

  if (!customerData?.subscriptionStatus || customerData.subscriptionStatus !== "active") {
    redirect("/pricing");
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
