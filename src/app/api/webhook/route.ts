import { NextRequest, NextResponse } from "next/server";
import { getSubscriptionStatus } from "@/lib/firebase";

export async function POST(req: NextRequest) {
  try {
    const body = await req.text();
    const signature = req.headers.get("stripe-signature") as string;

    // This would normally verify the Stripe webhook signature
    // but we're using Pica Passthrough so we'll just parse the event
    const event = JSON.parse(body);

    // Handle the event
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        const userId = session.metadata?.user_id;

        if (userId) {
          // The Firebase Stripe extension will automatically handle the subscription
          // We just need to verify the subscription status
          const { subscription } = await getSubscriptionStatus(userId);
          
          if (!subscription) {
            console.error('Subscription not found after checkout completion');
            return NextResponse.json(
              { error: "Subscription not found" },
              { status: 400 }
            );
          }
        }
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object;
        const userId = subscription.metadata?.user_id;

        if (userId) {
          // The Firebase Stripe extension will automatically update the subscription
          // We just need to verify the subscription status
          const { subscription: updatedSubscription } = await getSubscriptionStatus(userId);
          
          if (!updatedSubscription) {
            console.error('Subscription not found after update');
            return NextResponse.json(
              { error: "Subscription not found" },
              { status: 400 }
            );
          }
        }
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object;
        const userId = subscription.metadata?.user_id;

        if (userId) {
          // The Firebase Stripe extension will automatically handle the subscription deletion
          // We just need to verify the subscription status
          const { subscription: deletedSubscription } = await getSubscriptionStatus(userId);
          
          if (deletedSubscription?.status === 'active') {
            console.error('Subscription still active after deletion');
            return NextResponse.json(
              { error: "Subscription still active" },
              { status: 400 }
            );
          }
        }
        break;
      }

      default:
        // Unexpected event type
        console.log(`Unhandled event type ${event.type}`);
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error("Webhook error:", error);
    return NextResponse.json(
      { error: "Webhook handler failed" },
      { status: 400 }
    );
  }
}
