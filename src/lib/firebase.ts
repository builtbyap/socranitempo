import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { getFirestore, doc, updateDoc, getDoc, setDoc, getDocs, collection } from 'firebase/firestore';
import { getFunctions, httpsCallable, connectFunctionsEmulator } from 'firebase/functions';

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

// Configure functions to use the correct region and handle CORS
if (process.env.NODE_ENV === 'development') {
  connectFunctionsEmulator(functions, 'localhost', 5001);
}

// Set up CORS configuration for functions
const corsConfig = {
  origin: [
    'http://localhost:3000',
    'https://socrani.com',
    'https://socranitempo.vercel.app',
    'https://socrani-18328.web.app'
  ],
  credentials: true
};

export { app, auth, db, functions, corsConfig };

// Authentication functions
export const signIn = async (email: string, password: string) => {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    // Create customer record first if it doesn't exist
    const { success: createSuccess, error: createError } = await createCustomer(user.uid, email);
    if (!createSuccess) {
      console.error('Error creating customer:', createError);
      return { success: false, error: 'Failed to create customer record' };
    }

    // Wait a moment for the customer record to be fully created
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check subscription status in subcollection first
    const customerRef = doc(db, 'customers', user.uid);
    const subscriptionsSnapshot = await getDocs(collection(customerRef, 'subscriptions'));
    
    let subscription = null;
    let subError = null;

    if (!subscriptionsSnapshot.empty) {
      // Get the latest subscription
      const latestSubscription = subscriptionsSnapshot.docs[0].data();
      const currentPeriodEnd = latestSubscription.currentPeriodEnd?.toDate();
      const isExpired = currentPeriodEnd ? currentPeriodEnd < new Date() : true;
      
      if (latestSubscription.status === 'active' && !isExpired) {
        subscription = {
          status: latestSubscription.status,
          priceId: latestSubscription.priceId,
          currentPeriodEnd: currentPeriodEnd?.toISOString(),
          isExpired
        };
      }
    }

    // If no active subscription found in subcollection, check root document
    if (!subscription) {
      const { subscription: rootSubscription, error: rootError } = await getSubscriptionStatus(user.uid);
      if (rootSubscription?.status === 'active' && !rootSubscription.isExpired) {
        subscription = rootSubscription;
      }
      subError = rootError;
    }
    
    if (subError) {
      console.error('Error checking subscription:', subError);
      // Don't fail the sign-in if subscription check fails
      console.log('Continuing sign-in despite subscription check error');
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

    // Wait a moment for the customer record to be fully created
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check subscription status
    const { subscription, error: subError } = await getSubscriptionStatus(user.uid);
    if (subError) {
      console.error('Error checking subscription:', subError);
      // Don't fail the sign-up if subscription check fails
      console.log('Continuing sign-up despite subscription check error');
    }

    return { 
      success: true, 
      user,
      subscription: subscription || null
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
    if (!userId) {
      console.error('No userId provided to createCustomer');
      return { success: false, error: 'No user ID provided' };
    }

    console.log('Creating customer record for user:', userId, 'email:', email);

    // Call the Cloud Function to create the customer
    const createCustomerFunction = httpsCallable<{ email: string }, { success: boolean }>(
      functions,
      'createCustomer'
    );
    
    console.log('Calling createCustomer function...');
    const result = await createCustomerFunction({ email });
    console.log('Customer creation result:', result);
    
    if (!result.data?.success) {
      console.error('Failed to create customer record');
      return { 
        success: false, 
        error: 'Failed to create customer record'
      };
    }

    console.log('Customer record created successfully for user:', userId);
    return { success: true };
  } catch (error: any) {
    console.error('Error creating customer:', error);
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
    if (!userId) {
      console.error('No userId provided to getSubscriptionStatus');
      return { subscription: null, error: 'No user ID provided' };
    }

    console.log('Fetching subscription status for user:', userId);
    const userRef = doc(db, 'customers', userId);
    const docSnap = await getDoc(userRef);
    
    if (!docSnap.exists()) {
      console.log('No customer document found for user:', userId);
      // Try to create a customer record if it doesn't exist
      const { success, error: createError } = await createCustomer(userId, '');
      if (!success) {
        console.error('Failed to create customer record:', createError);
        return { subscription: null, error: 'Failed to create customer record' };
      }
      return { subscription: null };
    }
    
    const data = docSnap.data();
    console.log('Customer data:', data);
    
    // Check for subscription data in various possible locations
    let subscriptionStatus = null;
    let currentPeriodEnd = null;
    let priceId = null;

    // Check root document fields
    if (data.subscriptionStatus) {
      subscriptionStatus = data.subscriptionStatus;
      currentPeriodEnd = data.subscriptionEndDate?.toDate();
      priceId = data.stripePriceId;
    } else if (data.subscription?.status) {
      subscriptionStatus = data.subscription.status;
      currentPeriodEnd = data.subscription.currentPeriodEnd?.toDate();
      priceId = data.subscription.priceId;
    } else if (data.status) {
      subscriptionStatus = data.status;
      currentPeriodEnd = data.currentPeriodEnd?.toDate();
      priceId = data.priceId;
    }

    // If no subscription data found in root, check subcollection
    if (!subscriptionStatus) {
      const subscriptionsSnapshot = await getDocs(collection(userRef, 'subscriptions'));
      if (!subscriptionsSnapshot.empty) {
        const latestSubscription = subscriptionsSnapshot.docs[0].data();
        subscriptionStatus = latestSubscription.status;
        currentPeriodEnd = latestSubscription.currentPeriodEnd?.toDate();
        priceId = latestSubscription.priceId;
      }
    }

    // If still no subscription data found, return null
    if (!subscriptionStatus) {
      console.log('No valid subscription status found in customer data');
      console.log('Available fields:', Object.keys(data));
      return { subscription: null, error: 'No subscription found' };
    }

    // Check if the subscription is expired
    const now = new Date();
    const isExpired = currentPeriodEnd ? currentPeriodEnd < now : true;
    
    console.log('Subscription details:', {
      status: subscriptionStatus,
      currentPeriodEnd: currentPeriodEnd?.toISOString(),
      now: now.toISOString(),
      isExpired
    });
    
    // If subscription is expired, return null
    if (isExpired && subscriptionStatus === 'active') {
      console.log('Subscription expired for user:', userId);
      return { subscription: null, error: 'Subscription expired' };
    }

    const subscription = {
      status: subscriptionStatus,
      priceId: priceId,
      currentPeriodEnd: currentPeriodEnd?.toISOString(),
      isExpired
    };

    console.log('Returning subscription:', subscription);
    return { subscription };
  } catch (error: any) {
    console.error('Error getting subscription status:', error);
    return { 
      subscription: null, 
      error: error.message || 'Failed to get subscription status',
      details: error
    };
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
    provider.setCustomParameters({
      prompt: 'select_account'
    });

    const result = await signInWithPopup(auth, provider);
    const user = result.user;

    if (!user || !user.email) {
      console.error('No user or email after Google sign-in');
      return { success: false, error: 'Failed to get user information' };
    }

    console.log('Google sign-in successful, creating customer record...');

    // Create customer record
    const { success: createSuccess, error: createError } = await createCustomer(user.uid, user.email);
    if (!createSuccess) {
      console.error('Error creating customer:', createError);
      return { success: false, error: 'Failed to create customer record' };
    }

    console.log('Customer record created successfully');
    
    return { 
      success: true,
      user: {
        uid: user.uid,
        email: user.email,
        displayName: user.displayName
      }
    };
  } catch (error: any) {
    console.error('Error signing in with Google:', error);
    let errorMessage = 'Failed to sign in with Google';
    
    switch (error.code) {
      case 'auth/popup-closed-by-user':
        errorMessage = 'Sign-in popup was closed before completing the sign-in';
        break;
      case 'auth/cancelled-popup-request':
        errorMessage = 'Sign-in was cancelled';
        break;
      case 'auth/popup-blocked':
        errorMessage = 'Sign-in popup was blocked by the browser';
        break;
      case 'auth/network-request-failed':
        errorMessage = 'Network error occurred during sign-in';
        break;
    }
    
    return { success: false, error: errorMessage };
  }
}; 