import { NextResponse } from 'next/server';
import { auth } from '@/lib/firebase';
import { getStripe } from '@/lib/stripe';
import { getFunctions, httpsCallable } from 'firebase/functions';

// Define the response type for the getCustomerId function
interface CustomerIdResponse {
  customerId: string;
}

export async function POST(req: Request) {
  try {
    const user = auth.currentUser;
    if (!user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    // Get the customer ID from Firebase
    const functions = getFunctions();
    const getCustomerId = httpsCallable<unknown, CustomerIdResponse>(functions, 'ext-firestore-stripe-payments-getCustomerId');
    const { data } = await getCustomerId();

    if (!data.customerId) {
      return NextResponse.json(
        { error: 'No customer ID found' },
        { status: 400 }
      );
    }

    // Create a Stripe Customer Portal session
    const stripe = getStripe();
    const session = await stripe.billingPortal.sessions.create({
      customer: data.customerId,
      return_url: `${req.headers.get('origin')}/payment`,
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    console.error('Error creating portal session:', error);
    return NextResponse.json(
      { error: 'Failed to create portal session' },
      { status: 500 }
    );
  }
} 