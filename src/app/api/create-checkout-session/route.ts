import { NextRequest, NextResponse } from "next/server";
import { createCheckoutSession } from "@/lib/firebase";
import { auth } from "@/lib/firebase";
import { corsMiddleware, corsOptionsMiddleware } from "@/lib/cors";
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-02-24.acacia',
});

export async function POST(req: NextRequest) {
  try {
    // Apply CORS middleware
    const corsResponse = corsMiddleware(req);
    if (corsResponse.status !== 200) {
      return corsResponse;
    }

    const { priceId, customerId, successUrl, cancelUrl } = await req.json();

    if (!priceId || !customerId) {
      return NextResponse.json(
        { error: 'Price ID and customer ID are required' },
        { status: 400 }
      );
    }

    // Get the current user
    const user = auth.currentUser;
    if (!user) {
      return NextResponse.json(
        { error: "User must be authenticated" },
        { status: 401 }
      );
    }

    // Create a checkout session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: successUrl || `${req.headers.get('origin')}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl || `${req.headers.get('origin')}/pricing`,
      customer: customerId,
      allow_promotion_codes: true,
    });

    return NextResponse.json({ url: session.url });
  } catch (error: any) {
    console.error('Error creating checkout session:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to create checkout session' },
      { status: 500 }
    );
  }
}

// Handle CORS preflight requests
export async function OPTIONS(req: NextRequest) {
  return corsOptionsMiddleware(req);
} 