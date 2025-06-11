import { NextResponse } from 'next/server';
import { db } from '@/lib/firebase';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-02-24.acacia',
});

export async function POST(request: Request) {
  try {
    const { email, userId } = await request.json();

    if (!email || !userId) {
      return NextResponse.json(
        { error: 'Email and userId are required' },
        { status: 400 }
      );
    }

    // Create a new customer in Stripe
    const customer = await stripe.customers.create({
      email,
      metadata: {
        userId,
      },
    });

    // Store customer data in Firestore
    await setDoc(doc(db, 'customers', userId), {
      userId,
      email,
      stripeCustomerId: customer.id,
      createdAt: serverTimestamp(),
    });

    return NextResponse.json({ customerId: customer.id });
  } catch (error) {
    console.error('Error creating customer:', error);
    return NextResponse.json(
      { error: 'Failed to create customer' },
      { status: 500 }
    );
  }
} 