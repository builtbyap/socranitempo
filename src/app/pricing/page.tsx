import Footer from "@/components/footer";
import Navbar from "@/components/navbar";
import { Button } from "@/components/ui/button";
import { Check } from "lucide-react";
import Link from "next/link";

export default function PricingPage() {
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
            <div className="bg-white p-8 rounded-xl shadow-md border border-gray-100 flex flex-col h-full">
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
                <Button className="w-full">Subscribe Now</Button>
              </Link>
            </div>

            {/* Annual Plan */}
            <div className="bg-white p-8 rounded-xl shadow-md border border-blue-100 flex flex-col h-full relative overflow-hidden">
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
                <Button className="w-full bg-blue-600 hover:bg-blue-700">
                  Subscribe Now
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

      <Footer />
    </div>
  );
}
