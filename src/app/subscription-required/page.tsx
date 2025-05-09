import { Button } from "@/components/ui/button";
import Link from "next/link";
import { AlertCircle } from "lucide-react";

export default function SubscriptionRequired() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4 py-8">
      <div className="w-full max-w-md rounded-lg border border-border bg-card p-6 shadow-sm text-center">
        <div className="flex flex-col items-center gap-4">
          <AlertCircle className="h-12 w-12 text-red-500" />
          <h1 className="text-2xl font-semibold">Subscription Required</h1>
          <p className="text-muted-foreground">
            Your subscription has been cancelled. To access the dashboard and premium features, please resubscribe.
          </p>
          <div className="flex gap-4 mt-4">
            <Button asChild variant="outline">
              <Link href="/">Go Home</Link>
            </Button>
            <Button asChild>
              <Link href="/pricing">Resubscribe</Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
} 