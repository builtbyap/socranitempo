"use client";

import Navbar from "@/components/navbar";
import { Button } from "@/components/ui/button";
import { Check } from "lucide-react";
import Link from "next/link";
import { auth } from "@/lib/firebase/auth";
import { useState } from "react";

const handleSubscribe = async (priceId: string) => {
  try {
    const user = auth.currentUser;
    if (!user) {
      alert("Please sign in to subscribe");
      return;
    }

    console.log("Creating checkout session for user:", user.uid);
    console.log("Price ID:", priceId);

    const response = await fetch(
      "https://us-central1-socrani-18328.cloudfunctions.net/createCheckoutSession",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          priceId,
          userId: user.uid,
        }),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || "Failed to create checkout session");
    }

    const { sessionId, url } = await response.json();
    console.log("Checkout session created:", sessionId);
    window.location.href = url;
  } catch (error) {
    console.error("Error creating checkout session:", error);
    alert("Failed to process payment. Please try again.");
  }
};

export default function PricingPage() {
  const [loading, setLoading] = useState<string | null>(null);

  const onSubscribe = async (priceId: string) => {
    setLoading(priceId);
    try {
      await handleSubscribe(priceId);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-white to-gray-50">
      <Navbar />

      <section className="py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h1 className="text-4xl font-bold mb-4">
              Simple, Transparent Pricing
            </h1>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Choose the plan that works best for you and your team.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
            {/* Monthly Plan */}
            <div className="bg-white rounded-lg shadow-lg p-8 relative">
              <div className="mb-6">
                <h3 className="text-lg font-medium text-gray-500">Monthly</h3>
                <div className="mt-2 flex items-baseline">
                  <span className="text-4xl font-bold">$15</span>
                  <span className="ml-1 text-gray-500">/month</span>
                </div>
              </div>

              <ul className="space-y-4 mb-8 flex-grow">
                {[
                  "Full access to all features",
                  "Unlimited contacts",
                  "Priority support",
                  "Regular updates",
                  "Cancel anytime",
                ].map((feature, index) => (
                  <li key={index} className="flex items-start">
                    <Check className="h-5 w-5 text-green-500 mr-2 flex-shrink-0 mt-0.5" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>

              <Link href="/payment?plan=monthly" className="w-full">
                <Button className="w-full" onClick={() => onSubscribe('monthly')} disabled={loading === 'monthly'}>
                  {loading === 'monthly' ? 'Processing...' : 'Subscribe Now'}
                </Button>
              </Link>
            </div>

            {/* Annual Plan */}
            <div className="bg-white rounded-lg shadow-lg p-8 relative">
              <div className="absolute top-0 right-0 bg-blue-600 text-white px-3 py-1 text-xs font-medium rounded-bl-lg">
                Best Value
              </div>

              <div className="mb-6">
                <h3 className="text-lg font-medium text-gray-500">Annual</h3>
                <div className="mt-2 flex items-baseline">
                  <span className="text-4xl font-bold">$50</span>
                  <span className="ml-1 text-gray-500">/year</span>
                </div>
                <p className="text-sm text-green-600 mt-1">
                  Save $130 per year
                </p>
              </div>

              <ul className="space-y-4 mb-8 flex-grow">
                {[
                  "All monthly plan features",
                  "Unlimited contacts",
                  "Priority support",
                  "Regular updates",
                  "Advanced analytics",
                  "Dedicated account manager",
                ].map((feature, index) => (
                  <li key={index} className="flex items-start">
                    <Check className="h-5 w-5 text-green-500 mr-2 flex-shrink-0 mt-0.5" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>

              <Link href="/payment?plan=annual" className="w-full">
                <Button className="w-full bg-blue-600 hover:bg-blue-700" onClick={() => onSubscribe('annual')} disabled={loading === 'annual'}>
                  {loading === 'annual' ? 'Processing...' : 'Subscribe Now'}
                </Button>
              </Link>
            </div>
          </div>

          <div className="mt-12 text-center">
            <p className="text-gray-500">
              Need a custom plan for your enterprise?{" "}
              <a href="#" className="text-blue-600 font-medium">
                Contact us
              </a>
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
