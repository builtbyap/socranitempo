import { headers } from "next/headers";
import { NextResponse } from "next/server";
import Stripe from "stripe";
import { supabase } from "@/lib/supabase";

// Validate required environment variables
const requiredEnvVars = {
  STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET: process.env.STRIPE_WEBHOOK_SECRET,
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
};

// Check for missing environment variables
const missingEnvVars = Object.entries(requiredEnvVars)
  .filter(([_, value]) => !value)
  .map(([key]) => key);

if (missingEnvVars.length > 0) {
  throw new Error(
    `Missing required environment variables: ${missingEnvVars.join(", ")}`
  );
}

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2025-02-24.acacia",
});

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(req: Request) {
  try {
    const body = await req.text();
    const signature = headers().get("stripe-signature");

    if (!signature) {
      console.error("No Stripe signature found");
      return NextResponse.json(
        { error: "No signature found" },
        { status: 400 }
      );
    }

    let event: Stripe.Event;

    try {
      event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch (err) {
      console.error("Webhook signature verification failed:", err);
      return NextResponse.json(
        { error: "Webhook signature verification failed" },
        { status: 400 }
      );
    }

    console.log("Processing webhook event:", event.type);

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const customerId = session.customer as string;
        const subscriptionId = session.subscription as string;

        console.log("Processing checkout session:", {
          customerId,
          subscriptionId,
          userId: session.client_reference_id,
        });

        if (!session.client_reference_id) {
          console.error("No user ID found in session");
          return NextResponse.json(
            { error: "No user ID found" },
            { status: 400 }
          );
        }

        const { error: updateError } = await supabase
          .from("subs")
          .update({
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId,
            subscription_status: "active",
            subscription_end_date: new Date(
              (session.subscription as any).current_period_end * 1000
            ).toISOString(),
          })
          .eq("id", session.client_reference_id);

        if (updateError) {
          console.error("Error updating user subscription:", updateError);
          return NextResponse.json(
            { error: "Failed to update subscription" },
            { status: 500 }
          );
        }

        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const customerId = subscription.customer as string;

        console.log("Processing subscription update:", {
          customerId,
          subscriptionId: subscription.id,
          status: subscription.status,
        });

        const { data: user, error: fetchError } = await supabase
          .from("subs")
          .select("id")
          .eq("stripe_customer_id", customerId)
          .single();

        if (fetchError || !user) {
          console.error("Error fetching user:", fetchError);
          return NextResponse.json(
            { error: "User not found" },
            { status: 404 }
          );
        }

        const { error: updateError } = await supabase
          .from("subs")
          .update({
            subscription_status: subscription.status,
            subscription_end_date: new Date(
              subscription.current_period_end * 1000
            ).toISOString(),
          })
          .eq("id", user.id);

        if (updateError) {
          console.error("Error updating subscription:", updateError);
          return NextResponse.json(
            { error: "Failed to update subscription" },
            { status: 500 }
          );
        }

        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        const customerId = subscription.customer as string;

        console.log("Processing subscription deletion:", {
          customerId,
          subscriptionId: subscription.id,
        });

        const { data: user, error: fetchError } = await supabase
          .from("subs")
          .select("id")
          .eq("stripe_customer_id", customerId)
          .single();

        if (fetchError || !user) {
          console.error("Error fetching user:", fetchError);
          return NextResponse.json(
            { error: "User not found" },
            { status: 404 }
          );
        }

        const { error: updateError } = await supabase
          .from("subs")
          .update({
            subscription_status: "inactive",
            subscription_end_date: new Date().toISOString(),
          })
          .eq("id", user.id);

        if (updateError) {
          console.error("Error updating subscription:", updateError);
          return NextResponse.json(
            { error: "Failed to update subscription" },
            { status: 500 }
          );
        }

        break;
      }
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error("Webhook error:", error);
    return NextResponse.json(
      { error: "Webhook handler failed" },
      { status: 500 }
    );
  }
} 