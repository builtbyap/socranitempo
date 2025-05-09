import { headers } from "next/headers";
import { NextResponse } from "next/server";
import Stripe from "stripe";
import { supabase } from "@/lib/supabase";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2025-02-24.acacia",
});

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(req: Request) {
  try {
    const body = await req.text();
    const signature = headers().get("stripe-signature");

    if (!signature) {
      console.error("No Stripe signature found in headers");
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
        { error: "Invalid signature" },
        { status: 400 }
      );
    }

    console.log("Processing webhook event:", event.type);

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        
        if (!session.customer_email) {
          console.error("No customer email found in session");
          return NextResponse.json(
            { error: "No customer email found" },
            { status: 400 }
          );
        }

        const customerId = session.customer as string;
        const subscriptionId = session.subscription as string;

        console.log("Processing checkout completion:", {
          customerId,
          subscriptionId,
          customerEmail: session.customer_email
        });

        try {
          // Get the subscription details
          const subscription = await stripe.subscriptions.retrieve(subscriptionId);
          console.log("Subscription details:", subscription);

          // First, check if the user exists
          const { data: existingUser, error: userError } = await supabase
            .from("subs")
            .select("id")
            .eq("email", session.customer_email)
            .single();

          if (userError && userError.code !== "PGRST116") {
            console.error("Error checking existing user:", userError);
            return NextResponse.json(
              { error: "Failed to check existing user" },
              { status: 500 }
            );
          }

          if (!existingUser) {
            console.log("Creating new subscription record for:", session.customer_email);
            // Create new subscription record
            const { error: insertError } = await supabase
              .from("subs")
              .insert({
                id: session.customer_email,
                email: session.customer_email,
                subscription_status: "active",
                subscription_end_date: new Date(subscription.current_period_end * 1000).toISOString(),
                stripe_customer_id: customerId,
                stripe_subscription_id: subscriptionId,
              });

            if (insertError) {
              console.error("Error creating subscription record:", insertError);
              return NextResponse.json(
                { error: "Failed to create subscription record" },
                { status: 500 }
              );
            }
          } else {
            console.log("Updating existing subscription for:", session.customer_email);
            // Update existing subscription
            const { error: updateError } = await supabase
              .from("subs")
              .update({
                subscription_status: "active",
                subscription_end_date: new Date(subscription.current_period_end * 1000).toISOString(),
                stripe_customer_id: customerId,
                stripe_subscription_id: subscriptionId,
              })
              .eq("email", session.customer_email);

            if (updateError) {
              console.error("Error updating subscription:", updateError);
              return NextResponse.json(
                { error: "Failed to update subscription" },
                { status: 500 }
              );
            }
          }

          console.log("Successfully processed subscription");
        } catch (error) {
          console.error("Error processing subscription:", error);
          return NextResponse.json(
            { error: "Failed to process subscription" },
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
          status: subscription.status
        });

        try {
          const { error } = await supabase
            .from("subs")
            .update({
              subscription_status: subscription.status === "active" ? "active" : "cancelled",
              subscription_end_date: new Date(subscription.current_period_end * 1000).toISOString(),
            })
            .eq("stripe_customer_id", customerId);

          if (error) {
            console.error("Error updating subscription status:", error);
            return NextResponse.json(
              { error: "Failed to update subscription status" },
              { status: 500 }
            );
          }

          console.log("Successfully updated subscription status");
        } catch (error) {
          console.error("Error processing subscription update:", error);
          return NextResponse.json(
            { error: "Failed to process subscription update" },
            { status: 500 }
          );
        }
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        const customerId = subscription.customer as string;

        console.log("Processing subscription deletion:", { customerId });

        try {
          const { error } = await supabase
            .from("subs")
            .update({
              subscription_status: "cancelled",
              subscription_end_date: new Date().toISOString(),
            })
            .eq("stripe_customer_id", customerId);

          if (error) {
            console.error("Error cancelling subscription:", error);
            return NextResponse.json(
              { error: "Failed to cancel subscription" },
              { status: 500 }
            );
          }

          console.log("Successfully cancelled subscription");
        } catch (error) {
          console.error("Error processing subscription deletion:", error);
          return NextResponse.json(
            { error: "Failed to process subscription deletion" },
            { status: 500 }
          );
        }
        break;
      }
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error("Error processing webhook:", error);
    return NextResponse.json(
      { error: "Webhook handler failed" },
      { status: 500 }
    );
  }
} 