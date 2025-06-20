"use client";

import Navbar from "@/components/navbar";
import { Button } from "@/components/ui/button";
import { Check } from "lucide-react";
import Link from "next/link";

export default function PricingPage() {
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
              href="/sign-up"
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
            <Link
              href="/sign-up"
              className="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              Get started today
            </Link>
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
                  $50
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
                  Unlimited access
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
                  Custom solutions
                </li>
              </ul>
            </div>
            <Link
              href="/sign-up"
              className="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              Get started today
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
