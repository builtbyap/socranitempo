"use client";

import { useState } from 'react';
import { signInWithGoogle, auth } from '@/lib/firebase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import Link from 'next/link';

function SignInForm() {
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isRedirecting, setIsRedirecting] = useState(false);

  const handleGoogleSignIn = async () => {
    if (isRedirecting) {
      console.log('Already redirecting, ignoring sign-in attempt');
      return;
    }

    setError('');
    setIsLoading(true);
    try {
      console.log('Starting Google sign-in process...');
      const { success, error, subscription } = await signInWithGoogle();
      console.log('Sign-in result:', { success, error, subscription });
      
      if (success) {
        if (subscription) {
          const status = (subscription.status || '').toLowerCase();
          const isActive = status === 'active' && !subscription.isExpired;
          console.log('Subscription status:', status, 'Is active:', isActive, 'Subscription:', subscription);
          
          if (isActive) {
            console.log('User has active subscription, redirecting to dashboard...');
            setIsRedirecting(true);
            window.location.href = '/dashboard';
            return;
          }
        }
        
        console.log('No active subscription, redirecting to pricing page...');
        setIsRedirecting(true);
        window.location.href = '/pricing';
      } else {
        console.error('Sign-in failed:', error);
        setError(error || 'Failed to sign in with Google');
      }
    } catch (err) {
      console.error('Sign in error:', err);
      setError('An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  };

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
          {isLoading ? 'Signing in...' : isRedirecting ? 'Redirecting...' : 'Sign in with Google'}
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
