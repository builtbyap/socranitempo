import { NextRequest, NextResponse } from "next/server";
import { getSubscriptionStatus } from "@/lib/firebase";
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-02-24.acacia',
});

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(req: NextRequest) {
  try {
    const body = await req.text();
    const signature = req.headers.get("stripe-signature");

    if (!signature) {
      console.error('No Stripe signature found');
      return NextResponse.json(
        { error: "No signature found" },
        { status: 400 }
      );
    }

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch (err: any) {
      console.error(`Webhook signature verification failed: ${err.message}`);
      return NextResponse.json(
        { error: `Webhook signature verification failed: ${err.message}` },
        { status: 400 }
      );
    }

    console.log('Processing webhook event:', event.type);

    // Handle the event
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.user_id;

        if (userId) {
          console.log('Processing checkout.session.completed for user:', userId);
          
          // The Firebase Stripe extension will automatically handle the subscription
          // We just need to verify the subscription status
          const { subscription, error } = await getSubscriptionStatus(userId);
          
          if (error || !subscription) {
            console.error('Subscription not found after checkout completion:', error);
            return NextResponse.json(
              { error: "Subscription not found" },
              { status: 400 }
            );
          }

          console.log('Subscription found:', subscription);
        }
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata?.user_id;

        if (userId) {
          console.log('Processing customer.subscription.updated for user:', userId);
          
          // The Firebase Stripe extension will automatically update the subscription
          // We just need to verify the subscription status
          const { subscription: updatedSubscription, error } = await getSubscriptionStatus(userId);
          
          if (error || !updatedSubscription) {
            console.error('Subscription not found after update:', error);
            return NextResponse.json(
              { error: "Subscription not found" },
              { status: 400 }
            );
          }

          console.log('Updated subscription:', updatedSubscription);
        }
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata?.user_id;

        if (userId) {
          console.log('Processing customer.subscription.deleted for user:', userId);
          
          // The Firebase Stripe extension will automatically handle the subscription deletion
          // We just need to verify the subscription status
          const { subscription: deletedSubscription, error } = await getSubscriptionStatus(userId);
          
          if (error) {
            console.error('Error checking subscription status:', error);
            return NextResponse.json(
              { error: "Error checking subscription status" },
              { status: 400 }
            );
          }

          if (deletedSubscription?.status === 'active') {
            console.error('Subscription still active after deletion');
            return NextResponse.json(
              { error: "Subscription still active" },
              { status: 400 }
            );
          }

          console.log('Subscription successfully deleted');
        }
        break;
      }

      default:
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
