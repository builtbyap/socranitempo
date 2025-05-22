"use client";

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithGoogle } from '@/lib/firebase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import Link from 'next/link';
import Navbar from '@/components/navbar';

function SignUpForm() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleGoogleSignUp = async () => {
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
        setError(error || 'Failed to sign up with Google');
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
        <CardTitle>Sign Up</CardTitle>
        <CardDescription>Create your account using Google</CardDescription>
      </CardHeader>
      <CardContent>
        <Button onClick={handleGoogleSignUp} disabled={isLoading} className="w-full">
          {isLoading ? 'Signing up...' : 'Sign up with Google'}
        </Button>
        {error && <div className="text-red-500 text-sm mt-4">{error}</div>}
      </CardContent>
      <CardFooter className="flex flex-col space-y-4">
        <div className="text-sm text-muted-foreground">
          Already have an account?{' '}
          <Link href="/sign-in" className="text-primary hover:underline">
            Sign in
          </Link>
        </div>
      </CardFooter>
    </Card>
  );
}

export default function SignUpPage() {
  return (
    <>
      <Navbar />
      <div className="container flex h-screen w-screen flex-col items-center justify-center">
        <SignUpForm />
      </div>
    </>
  );
}
