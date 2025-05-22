import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore, doc, updateDoc, getDoc, collection } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// Initialize Firebase
const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
const auth = getAuth(app);
const db = getFirestore(app);
const functions = getFunctions(app);

export { app, auth, db, functions };

interface CheckoutSessionResponse {
  sessionId: string;
}

interface CustomerPortalResponse {
  url: string;
}

// Function to create a Stripe checkout session
export const createCheckoutSession = async (priceId: string) => {
  try {
    const createCheckoutSession = httpsCallable<{ priceId: string }, CheckoutSessionResponse>(
      functions,
      'ext-firebase-stripe-createCheckoutSession'
    );
    const { data } = await createCheckoutSession({ priceId });
    return { success: true, sessionId: data.sessionId };
  } catch (error) {
    console.error('Error creating checkout session:', error);
    return { success: false, error };
  }
};

// Function to get customer portal URL
export const getCustomerPortalUrl = async () => {
  try {
    const getCustomerPortalUrl = httpsCallable<{}, CustomerPortalResponse>(
      functions,
      'ext-firebase-stripe-getCustomerPortalUrl'
    );
    const { data } = await getCustomerPortalUrl();
    return { success: true, url: data.url };
  } catch (error) {
    console.error('Error getting customer portal URL:', error);
    return { success: false, error };
  }
};

// Function to get subscription status
export const getSubscriptionStatus = async (userId: string) => {
  try {
    const userRef = doc(db, 'customers', userId);
    const docSnap = await getDoc(userRef);
    
    if (!docSnap.exists()) {
      return { subscription: null };
    }
    
    const data = docSnap.data();
    return { 
      subscription: {
        status: data.subscriptionStatus,
        priceId: data.priceId,
        currentPeriodEnd: data.currentPeriodEnd,
      }
    };
  } catch (error) {
    console.error('Error getting subscription status:', error);
    return { subscription: null, error };
  }
};

// Function to handle successful payment
export const handleSuccessfulPayment = async (userId: string, sessionId: string) => {
  try {
    const handleSuccessfulPayment = httpsCallable<{ sessionId: string }, void>(
      functions,
      'ext-firebase-stripe-handleSuccessfulPayment'
    );
    await handleSuccessfulPayment({ sessionId });
    return { success: true };
  } catch (error) {
    console.error('Error handling successful payment:', error);
    return { success: false, error };
  }
};

// Function to update user subscription status in Firebase
export const updateFirebaseSubscription = async (
  userId: string,
  subscriptionData: {
    status: string;
    type: string;
    startDate: string;
    endDate: string;
  }
) => {
  try {
    const userRef = doc(db, 'users', userId);
    await updateDoc(userRef, {
      subscription: subscriptionData,
      updatedAt: new Date().toISOString(),
    });
    return { success: true };
  } catch (error) {
    console.error('Error updating Firebase subscription:', error);
    return { success: false, error };
  }
};

// Function to get user subscription status from Firebase
export const getFirebaseSubscription = async (userId: string) => {
  try {
    const userRef = doc(db, 'users', userId);
    const docSnap = await getDoc(userRef);
    
    if (!docSnap.exists()) {
      return { subscription: null };
    }
    
    const data = docSnap.data();
    return { subscription: data?.subscription || null };
  } catch (error) {
    console.error('Error getting Firebase subscription:', error);
    return { subscription: null, error };
  }
}; 