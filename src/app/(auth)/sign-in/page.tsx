"use client";

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithGoogle } from '@/lib/firebase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import Link from 'next/link';

function SignInForm() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleGoogleSignIn = async () => {
    setError('');
    setIsLoading(true);
    try {
      const { success, error, subscription } = await signInWithGoogle();
      if (success) {
        if (subscription?.status === 'active') {
          router.push('/dashboard');
        } else {
          router.push('/payment');
        }
      } else {
        setError(error || 'Failed to sign in with Google');
      }
    } catch (err) {
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
        <Button onClick={handleGoogleSignIn} disabled={isLoading} className="w-full">
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
