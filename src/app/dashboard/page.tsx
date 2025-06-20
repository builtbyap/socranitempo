"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import DashboardNavbar from "@/components/dashboard-navbar";
import DashboardTabs from "@/components/dashboard/tabs";
import { InfoIcon } from "lucide-react";
import { auth } from "@/lib/firebase";
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
            window.location.href = "/sign-in";
          }
        }, 500);
        return;
      }

      // User is authenticated, allow access to dashboard
      console.log("User authenticated, allowing access to dashboard");
      setIsLoading(false);
    });

    return () => {
      isMounted = false;
      if (redirectTimeout) {
        clearTimeout(redirectTimeout);
      }
      unsubscribe();
    };
  }, []);

  if (isRedirecting) {
    return (
      <div className="fixed inset-0 bg-background/80 backdrop-blur-sm">
        <div className="container flex h-screen w-screen flex-col items-center justify-center">
          <div className="text-lg">Redirecting...</div>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="fixed inset-0 bg-background/80 backdrop-blur-sm">
        <div className="container flex h-screen w-screen flex-col items-center justify-center">
          <div className="text-lg">Loading dashboard...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="fixed inset-0 bg-background/80 backdrop-blur-sm">
        <div className="container flex h-screen w-screen flex-col items-center justify-center">
          <div className="text-red-500">{error}</div>
        </div>
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
