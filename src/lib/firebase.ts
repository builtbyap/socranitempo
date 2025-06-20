import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { getFirestore, doc, updateDoc, getDoc, setDoc } from 'firebase/firestore';
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

    return { 
      success: true, 
      user
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
      user
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

    const result = await createCustomerFunction({ email });
    return { success: result.data.success };
  } catch (error: any) {
    console.error('Error creating customer:', error);
    
    // If the function fails, try to create the customer document directly
    try {
      console.log('Attempting to create customer document directly in Firestore');
      const customerRef = doc(db, 'customers', userId);
      await setDoc(customerRef, {
        email,
        created: new Date(),
        updatedAt: new Date()
      });
      console.log('Customer document created successfully in Firestore');
      return { success: true };
    } catch (firestoreError) {
      console.error('Error creating customer document in Firestore:', firestoreError);
      return { success: false, error: 'Failed to create customer record' };
    }
  }
};

// Google Sign In
export const signInWithGoogle = async () => {
  try {
    const provider = new GoogleAuthProvider();
    const result = await signInWithPopup(auth, provider);
    const user = result.user;

    // Create customer record
    const { success: createSuccess, error: createError } = await createCustomer(user.uid, user.email || '');
    if (!createSuccess) {
      console.error('Error creating customer:', createError);
      return { success: false, error: 'Failed to create customer record' };
    }

    return { success: true, user };
  } catch (error: any) {
    console.error('Error signing in with Google:', error);
    let errorMessage = 'Failed to sign in with Google';
    
    switch (error.code) {
      case 'auth/popup-closed-by-user':
        errorMessage = 'Sign in was cancelled';
        break;
      case 'auth/popup-blocked':
        errorMessage = 'Sign in popup was blocked. Please allow popups for this site';
        break;
      case 'auth/account-exists-with-different-credential':
        errorMessage = 'An account already exists with the same email address but different sign-in credentials';
        break;
    }
    
    return { success: false, error: errorMessage };
  }
}; 