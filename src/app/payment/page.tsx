import { redirect } from "next/navigation";
import { createClient } from "../../../supabase/server";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { CheckIcon, InfoIcon } from "lucide-react";
import Link from "next/link";

export default async function PaymentPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return redirect("/sign-in");
  }

  // Fetch user data including subscription status
  const { data: userData } = await supabase
    .from("users")
    .select("subscription_status, subscription_type, subscription_end_date")
    .eq("user_id", user.id)
    .single();

  const isSubscribed = userData?.subscription_status === "active";
  const subscriptionType = userData?.subscription_type;
  const subscriptionEndDate = userData?.subscription_end_date
    ? new Date(userData.subscription_end_date).toLocaleDateString()
    : null;

  return (
    <main className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">Subscription</h1>

        {isSubscribed ? (
          <div className="bg-green-50 border border-green-200 rounded-lg p-6 mb-8">
            <div className="flex items-center gap-3 mb-2">
              <CheckIcon className="text-green-600" />
              <h2 className="text-xl font-semibold text-green-800">
                Active Subscription
              </h2>
            </div>
            <p className="text-green-700 mb-4">
              You have an active {subscriptionType} subscription that expires on{" "}
              {subscriptionEndDate}.
            </p>
            <Link href="/dashboard">
              <Button>Go to Dashboard</Button>
            </Link>
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
          <Card>
            <CardHeader>
              <CardTitle>Monthly</CardTitle>
              <CardDescription>Perfect for short-term needs</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-2">$15</div>
              <p className="text-muted-foreground">Billed monthly</p>
              <ul className="mt-4 space-y-2">
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Full access to all features</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Priority support</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Cancel anytime</span>
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button
                className="w-full"
                onClick={() =>
                  alert("Monthly subscription processing would happen here")
                }
              >
                Subscribe Monthly
              </Button>
            </CardFooter>
          </Card>

          <Card className="border-primary">
            <CardHeader>
              <CardTitle>Annual</CardTitle>
              <CardDescription>Best value for long-term use</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold mb-2">$50</div>
              <p className="text-muted-foreground">
                Billed annually (Save $130)
              </p>
              <ul className="mt-4 space-y-2">
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>All monthly features</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Premium support</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckIcon className="h-4 w-4 text-green-500" />
                  <span>Two months free</span>
                </li>
              </ul>
            </CardContent>
            <CardFooter>
              <Button
                variant="default"
                className="w-full"
                onClick={() =>
                  alert("Annual subscription processing would happen here")
                }
              >
                Subscribe Annually
              </Button>
            </CardFooter>
          </Card>
        </div>
      </div>
    </main>
  );
}
