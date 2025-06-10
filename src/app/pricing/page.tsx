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

    // Get a fresh ID token
    const idToken = await user.getIdToken(true);
    if (!idToken) {
      throw new Error("Failed to get authentication token");
    }

    // Validate price ID format
    if (!priceId.startsWith("price_")) {
      throw new Error("Invalid price ID format");
    }

    const response = await fetch(
      "https://us-central1-socrani-18328.cloudfunctions.net/createCheckoutSession",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          priceId,
        }),
        credentials: "include",
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      console.error("Server error:", errorData);
      throw new Error(errorData.error || "Failed to create checkout session");
    }

    const data = await response.json();
    if (!data.url) {
      console.error("No URL in response:", data);
      throw new Error("No checkout URL received");
    }

    console.log("Redirecting to checkout:", data.url);
    window.location.href = data.url;
  } catch (error) {
    console.error("Payment error:", error);
    alert(error instanceof Error ? error.message : "An error occurred while processing your payment");
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
    <div className="py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-6 lg:px-8">
        <div className="mx-auto max-w-4xl text-center">
          <h2 className="text-base font-semibold leading-7 text-indigo-600">
            Pricing
          </h2>
          <p className="mt-2 text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl">
            Choose the right plan for&nbsp;you
          </p>
        </div>
        <p className="mx-auto mt-6 max-w-2xl text-center text-lg leading-8 text-gray-600">
          Choose the perfect plan for your needs. All plans include a 14-day free
          trial.
        </p>
        <div className="isolate mx-auto mt-16 grid max-w-md grid-cols-1 gap-y-8 sm:mt-20 lg:mx-0 lg:max-w-none lg:grid-cols-3">
          {/* Free Plan */}
          <div className="flex flex-col justify-between rounded-3xl bg-white p-8 ring-1 ring-gray-200 xl:p-10">
            <div>
              <div className="flex items-center justify-between gap-x-4">
                <h3
                  id="tier-free"
                  className="text-lg font-semibold leading-8 text-gray-900"
                >
                  Free
                </h3>
              </div>
              <p className="mt-4 text-sm leading-6 text-gray-600">
                Perfect for trying out our service.
              </p>
              <p className="mt-6 flex items-baseline gap-x-1">
                <span className="text-4xl font-bold tracking-tight text-gray-900">
                  $0
                </span>
                <span className="text-sm font-semibold leading-6 text-gray-600">
                  /month
                </span>
              </p>
              <ul
                role="list"
                className="mt-8 space-y-3 text-sm leading-6 text-gray-600"
              >
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Basic features
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Limited access
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Community support
                </li>
              </ul>
            </div>
            <Link
              href="/signup"
              className="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              Get started today
            </Link>
          </div>

          {/* Pro Plan */}
          <div className="flex flex-col justify-between rounded-3xl bg-white p-8 ring-1 ring-gray-200 xl:p-10">
            <div>
              <div className="flex items-center justify-between gap-x-4">
                <h3
                  id="tier-pro"
                  className="text-lg font-semibold leading-8 text-gray-900"
                >
                  Pro
                </h3>
                <p className="rounded-full bg-indigo-600/10 px-2.5 py-1 text-xs font-semibold leading-5 text-indigo-600">
                  Most popular
                </p>
              </div>
              <p className="mt-4 text-sm leading-6 text-gray-600">
                Everything you need for your business.
              </p>
              <p className="mt-6 flex items-baseline gap-x-1">
                <span className="text-4xl font-bold tracking-tight text-gray-900">
                  $15
                </span>
                <span className="text-sm font-semibold leading-6 text-gray-600">
                  /month
                </span>
              </p>
              <ul
                role="list"
                className="mt-8 space-y-3 text-sm leading-6 text-gray-600"
              >
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  All Free features
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Advanced features
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Priority support
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Custom integrations
                </li>
              </ul>
            </div>
            <button
              onClick={() => onSubscribe("price_1RYHRjCyTrsNmVMYWjpG3SDR")}
              disabled={loading === "price_1RYHRjCyTrsNmVMYWjpG3SDR"}
              className="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading === "price_1RYHRjCyTrsNmVMYWjpG3SDR"
                ? "Processing..."
                : "Subscribe now"}
            </button>
          </div>

          {/* Enterprise Plan */}
          <div className="flex flex-col justify-between rounded-3xl bg-white p-8 ring-1 ring-gray-200 xl:p-10">
            <div>
              <div className="flex items-center justify-between gap-x-4">
                <h3
                  id="tier-enterprise"
                  className="text-lg font-semibold leading-8 text-gray-900"
                >
                  Enterprise
                </h3>
              </div>
              <p className="mt-4 text-sm leading-6 text-gray-600">
                For large organizations with custom needs.
              </p>
              <p className="mt-6 flex items-baseline gap-x-1">
                <span className="text-4xl font-bold tracking-tight text-gray-900">
                  $49
                </span>
                <span className="text-sm font-semibold leading-6 text-gray-600">
                  /month
                </span>
              </p>
              <ul
                role="list"
                className="mt-8 space-y-3 text-sm leading-6 text-gray-600"
              >
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  All Pro features
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Custom solutions
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Dedicated support
                </li>
                <li className="flex gap-x-3">
                  <Check
                    className="h-6 w-5 flex-none text-indigo-600"
                    aria-hidden="true"
                  />
                  Advanced analytics
                </li>
              </ul>
            </div>
            <button
              onClick={() => onSubscribe("price_1RYHRjCyTrsNmVMYWjpG3SDR")}
              disabled={loading === "price_1RYHRjCyTrsNmVMYWjpG3SDR"}
              className="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading === "price_1RYHRjCyTrsNmVMYWjpG3SDR"
                ? "Processing..."
                : "Subscribe now"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
