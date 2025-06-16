"use client";

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithGoogle, auth } from '@/lib/firebase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import Link from 'next/link';
import { onAuthStateChanged } from 'firebase/auth';

function SignInForm() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isRedirecting, setIsRedirecting] = useState(false);

  // Check if user is already authenticated
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        console.log('User authenticated, redirecting to dashboard...');
        setIsRedirecting(true);
        // Use window.location for a full page reload to ensure proper state
        window.location.href = '/dashboard';
      }
    });

    return () => unsubscribe();
  }, []);

  const handleGoogleSignIn = async () => {
    if (isLoading || isRedirecting) return;
    
    setError('');
    setIsLoading(true);
    try {
      const { success, error } = await signInWithGoogle();
      
      if (!success) {
        setError(error || 'Failed to sign in with Google');
      }
      // Don't redirect here - let the auth state listener handle it
    } catch (err) {
      console.error('Sign in error:', err);
      setError('An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  if (isRedirecting) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Sign In</CardTitle>
          <CardDescription>Redirecting to dashboard...</CardDescription>
        </CardHeader>
        <CardContent className="flex justify-center">
          <div className="text-muted-foreground">Please wait...</div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="w-[350px]">
      <CardHeader>
        <CardTitle>Sign In</CardTitle>
        <CardDescription>Sign in to your account using Google</CardDescription>
      </CardHeader>
      <CardContent>
        <Button 
          onClick={handleGoogleSignIn} 
          disabled={isLoading || isRedirecting} 
          className="w-full"
        >
          {isLoading ? 'Signing in...' : 'Sign in with Google'}
        </Button>
        {error && <div className="text-red-500 text-sm mt-4">{error}</div>}
      </CardContent>
      <CardFooter className="flex flex-col space-y-4">
        <div className="text-sm text-muted-foreground">
          Don't have an account?{' '}
          <Link href="/sign-up" className="text-primary hover:underline">
            Sign up
          </Link>
        </div>
      </CardFooter>
    </Card>
  );
}

export default function SignInPage() {
  return (
    <div className="container flex h-screen w-screen flex-col items-center justify-center">
      <SignInForm />
    </div>
  );
}
