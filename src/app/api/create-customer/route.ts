import { NextResponse } from 'next/server';
import { auth } from '@/lib/firebase';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

export async function POST(request: Request) {
  try {
    const user = auth.currentUser;
    if (!user || !user.email) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    // Create a customer in Stripe
    const customer = await stripe.customers.create({
      email: user.email,
      metadata: {
        firebaseUID: user.uid,
      },
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