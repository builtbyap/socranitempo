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

  useEffect(() => {
    let isMounted = true;
    let authTimeout: NodeJS.Timeout;

    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (!isMounted) return;

      if (user) {
        console.log('User authenticated, preparing to redirect...');
        setIsLoading(false);
        setIsRedirecting(true);
        
        // Add a small delay to ensure state updates are complete
        authTimeout = setTimeout(() => {
          if (isMounted) {
            console.log('Redirecting to dashboard...');
            // Use replace instead of push to prevent back button issues
            router.replace('/dashboard');
          }
        }, 1000);
      }
    });

    return () => {
      isMounted = false;
      if (authTimeout) {
        clearTimeout(authTimeout);
      }
      unsubscribe();
    };
  }, [router]);

  const handleGoogleSignIn = async () => {
    if (isLoading || isRedirecting) return;
    
    setError('');
    setIsLoading(true);
    try {
      const result = await signInWithGoogle();
      
      if (!result.success) {
        setError(result.error || 'Failed to sign in with Google');
        setIsLoading(false);
      }
    } catch (err) {
      console.error('Sign in error:', err);
      setError('An unexpected error occurred');
      setIsLoading(false);
    }
  };

  if (isRedirecting) {
    return (
      <div className="fixed inset-0 bg-background/80 backdrop-blur-sm">
        <Card className="w-[350px] absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
          <CardHeader>
            <CardTitle>Sign In</CardTitle>
            <CardDescription>Redirecting to dashboard...</CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <div className="text-muted-foreground">Please wait...</div>
          </CardContent>
        </Card>
      </div>
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
