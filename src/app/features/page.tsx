import Navbar from "@/components/navbar";
import { Button } from "@/components/ui/button";
import {
  ArrowRight,
  CheckCircle2,
  Shield,
  Users,
  Zap,
  Search,
  Filter,
  Clock,
  Database,
} from "lucide-react";
import Link from "next/link";

export default function FeaturesPage() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-white to-gray-50">
      <Navbar />

      <section className="py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h1 className="text-4xl font-bold mb-4">Powerful Features</h1>
            <p className="text-gray-600 max-w-2xl mx-auto">
              Discover all the tools and features that make our Business Contact
              Directory the best choice for professionals.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {[
              {
                icon: <Shield className="w-8 h-8" />,
                title: "Secure Authentication",
                description:
                  "Enterprise-grade security with Firebase Google Sign-in integration to keep your data protected.",
              },
              {
                icon: <Database className="w-8 h-8" />,
                title: "Comprehensive Directory",
                description:
                  "Access a vast database of business contacts across various industries and companies.",
              },
              {
                icon: <Users className="w-8 h-8" />,
                title: "Team Collaboration",
                description:
                  "Share contacts and notes with your team members for better collaboration.",
              },
              {
                icon: <Search className="w-8 h-8" />,
                title: "Advanced Search",
                description:
                  "Find exactly who you're looking for with our powerful search and filtering capabilities.",
              },
              {
                icon: <Filter className="w-8 h-8" />,
                title: "Smart Filtering",
                description:
                  "Filter contacts by company, department, position, or any custom criteria you need.",
              },
              {
                icon: <Clock className="w-8 h-8" />,
                title: "Recent Contacts",
                description:
                  "Quickly access your most recently viewed contacts for improved productivity.",
              },
              {
                icon: <Zap className="w-8 h-8" />,
                title: "Quick Copy",
                description:
                  "Copy contact details with a single click to use in emails, messages, or documents.",
              },
              {
                icon: <CheckCircle2 className="w-8 h-8" />,
                title: "99.9% Uptime",
                description:
                  "Rely on our robust infrastructure with guaranteed uptime for uninterrupted access.",
              },
            ].map((feature, index) => (
              <div
                key={index}
                className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow"
              >
                <div className="text-blue-600 mb-4">{feature.icon}</div>
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-gray-600 mb-4">{feature.description}</p>
              </div>
            ))}
          </div>

          <div className="mt-16 text-center">
            <h2 className="text-2xl font-bold mb-6">Ready to get started?</h2>
            <div className="flex justify-center">
              <Link href="/pricing">
                <Button className="px-6 py-3 text-lg flex items-center">
                  View Pricing
                  <ArrowRight className="ml-2 w-5 h-5" />
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
