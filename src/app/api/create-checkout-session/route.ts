import { NextRequest, NextResponse } from "next/server";
import { createCheckoutSession } from "@/lib/firebase";
import { auth } from "@/lib/firebase";
import { corsMiddleware, corsOptionsMiddleware } from "@/lib/cors";
import Stripe from 'stripe';
import { db } from '@/lib/firebase';
import { doc, getDoc } from 'firebase/firestore';

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

    const { priceId, customerId, userId, successUrl, cancelUrl } = await req.json();

    if (!priceId || !customerId || !userId) {
      return NextResponse.json(
        { error: 'Price ID, customer ID, and user ID are required' },
        { status: 400 }
      );
    }

    // Verify customer exists in Firestore
    const customerRef = doc(db, 'customers', userId);
    const customerDoc = await getDoc(customerRef);

    if (!customerDoc.exists()) {
      return NextResponse.json(
        { error: 'Customer not found' },
        { status: 404 }
      );
    }

    // Create Stripe checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        userId,
      },
    });

    return NextResponse.json({ sessionId: session.id });
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