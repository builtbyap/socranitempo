import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { getFirestore, doc, updateDoc, getDoc } from 'firebase/firestore';
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
const functions = getFunctions(app, 'us-central1');

export { app, auth, db, functions };

// Authentication functions
export const signIn = async (email: string, password: string) => {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    // Check subscription status
    const { subscription, error: subError } = await getSubscriptionStatus(user.uid);
    
    if (subError) {
      console.error('Error checking subscription:', subError);
      return { success: false, error: 'Failed to verify subscription status' };
    }

    // If no subscription exists, create a customer record
    if (!subscription) {
      const { success: createSuccess, error: createError } = await createCustomer(user.uid, email);
      if (!createSuccess) {
        console.error('Error creating customer:', createError);
        return { success: false, error: 'Failed to create customer record' };
      }
    }

    return { 
      success: true, 
      user,
      subscription: subscription || null
    };
  } catch (error: any) {
    console.error('Error signing in:', error);
    let errorMessage = 'Failed to sign in';
    
    switch (error.code) {
      case 'auth/operation-not-allowed':
        errorMessage = 'Email/password sign in is not enabled. Please contact support.';
        break;
      case 'auth/user-not-found':
      case 'auth/wrong-password':
        errorMessage = 'Invalid email or password';
        break;
      case 'auth/invalid-email':
        errorMessage = 'Invalid email address';
        break;
      case 'auth/user-disabled':
        errorMessage = 'This account has been disabled';
        break;
      case 'auth/too-many-requests':
        errorMessage = 'Too many failed attempts. Please try again later';
        break;
    }
    
    return { success: false, error: errorMessage };
  }
};

export const signUp = async (email: string, password: string) => {
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    // Create customer record
    const { success: createSuccess, error: createError } = await createCustomer(user.uid, email);
    if (!createSuccess) {
      console.error('Error creating customer:', createError);
      return { success: false, error: 'Failed to create customer record' };
    }

    return { 
      success: true, 
      user,
      subscription: null // New users don't have a subscription yet
    };
  } catch (error: any) {
    console.error('Error signing up:', error);
    let errorMessage = 'Failed to sign up';
    
    switch (error.code) {
      case 'auth/operation-not-allowed':
        errorMessage = 'Email/password sign up is not enabled. Please contact support.';
        break;
      case 'auth/email-already-in-use':
        errorMessage = 'An account with this email already exists';
        break;
      case 'auth/invalid-email':
        errorMessage = 'Invalid email address';
        break;
      case 'auth/weak-password':
        errorMessage = 'Password is too weak. Please use a stronger password';
        break;
    }
    
    return { success: false, error: errorMessage };
  }
};

export const logOut = async () => {
  try {
    await signOut(auth);
    return { success: true };
  } catch (error: any) {
    console.error('Error signing out:', error);
    return { success: false, error: error.message };
  }
};

// Function to create a customer record
export const createCustomer = async (userId: string, email: string) => {
  try {
    // First, check if the customer already exists
    const userRef = doc(db, 'customers', userId);
    const docSnap = await getDoc(userRef);
    
    if (docSnap.exists()) {
      console.log('Customer already exists');
      return { success: true };
    }

    // Create the customer using the Firebase Stripe extension
    const createCustomer = httpsCallable<{ userId: string, email: string }, void>(
      functions,
      'ext-firebase-stripe-createCustomer'
    );
    
    const result = await createCustomer({ userId, email });
    console.log('Customer creation result:', result);
    
    // Verify the customer was created
    const verifyDoc = await getDoc(userRef);
    if (!verifyDoc.exists()) {
      throw new Error('Customer record was not created in Firestore');
    }
    
    return { success: true };
  } catch (error: any) {
    console.error('Error creating customer:', error);
    // Return more detailed error information
    return { 
      success: false, 
      error: error.message || 'Failed to create customer record',
      details: error.details || error,
      code: error.code || 'unknown'
    };
  }
};

// Subscription functions
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

// Function to create a Stripe checkout session
export const createCheckoutSession = async (priceId: string) => {
  try {
    const createCheckoutSession = httpsCallable<{ priceId: string }, { sessionId: string }>(
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
    const getCustomerPortalUrl = httpsCallable<{}, { url: string }>(
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

export const signInWithGoogle = async () => {
  try {
    const provider = new GoogleAuthProvider();
    const result = await signInWithPopup(auth, provider);
    const user = result.user;

    // Check subscription status
    const { subscription, error: subError } = await getSubscriptionStatus(user.uid);
    if (subError) {
      console.error('Error checking subscription:', subError);
      return { success: false, error: 'Failed to verify subscription status' };
    }

    // If no subscription exists, create a customer record
    if (!subscription) {
      const { success: createSuccess, error: createError } = await createCustomer(user.uid, user.email || '');
      if (!createSuccess) {
        console.error('Error creating customer:', createError);
        return { success: false, error: 'Failed to create customer record' };
      }
    }

    return {
      success: true,
      user,
      subscription: subscription || null
    };
  } catch (error: any) {
    console.error('Error signing in with Google:', error);
    return { success: false, error: error.message || 'Failed to sign in with Google' };
  }
}; 