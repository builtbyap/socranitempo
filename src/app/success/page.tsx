"use client";

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { onAuthStateChanged, User } from 'firebase/auth';
import { auth } from '@/lib/firebase/auth';
import { doc, onSnapshot, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase/db';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { Suspense } from 'react';

export default function SuccessPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <Suspense fallback={
        <Card className="w-[350px]">
          <CardHeader>
            <CardTitle>Processing Payment</CardTitle>
            <CardDescription>Please wait while we process your payment details...</CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
          </CardContent>
        </Card>
      }>
        <SuccessContent />
      </Suspense>
    </div>
  );
}

function SuccessContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const [success, setSuccess] = useState(false);
  const maxRetries = 3;

  useEffect(() => {
    const processPayment = async () => {
      try {
        const sessionId = searchParams.get('session_id');
        if (!sessionId) {
          throw new Error('No session ID found in URL');
        }

        console.log('Processing payment for session:', sessionId);

        // Wait for authentication
        const user = await new Promise<User>((resolve, reject) => {
          const unsubscribe = onAuthStateChanged(auth, (user) => {
            unsubscribe();
            if (user) {
              resolve(user);
            } else if (retryCount < maxRetries) {
              console.log(`User not authenticated, retry ${retryCount + 1}/${maxRetries}`);
              setRetryCount(prev => prev + 1);
              setTimeout(() => {
                processPayment();
              }, 2000);
            } else {
              reject(new Error('Authentication required'));
            }
          });
        });

        if (!user) {
          throw new Error('Authentication required');
        }

        // Call the Firebase function
        const response = await fetch('https://us-central1-socrani-18328.cloudfunctions.net/handleSuccessfulPayment', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify({ 
            sessionId,
            userId: user.uid 
          }),
          mode: 'cors',
          credentials: 'include'
        });

        if (!response.ok) {
          const errorData = await response.json().catch(() => ({ error: 'Failed to process payment' }));
          throw new Error(errorData.error || 'Failed to process payment');
        }

        const result = await response.json();
        console.log('Payment processed successfully:', result);

        if (result.success) {
          setSuccess(true);
          // Wait for 2 seconds to show success message
          setTimeout(() => {
            router.push('/dashboard');
          }, 2000);
        } else {
          throw new Error(result.error || 'Payment processing failed');
        }
      } catch (err: any) {
        console.error('Error processing payment:', err);
        setError(err.message || 'An error occurred while processing your payment');
      } finally {
        setLoading(false);
      }
    };

    processPayment();
  }, [searchParams, router, retryCount]);

  if (loading) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Processing Payment</CardTitle>
          <CardDescription>Please wait while we process your payment...</CardDescription>
        </CardHeader>
        <CardContent className="flex justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Payment Error</CardTitle>
          <CardDescription>{error}</CardDescription>
        </CardHeader>
        <CardFooter className="flex justify-between">
          <Button variant="outline" onClick={() => router.push('/pricing')}>
            Return to Pricing
          </Button>
          {error.includes('Authentication required') && (
            <Button onClick={() => router.push('/signin')}>
              Sign In
            </Button>
          )}
        </CardFooter>
      </Card>
    );
  }

  if (success) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Payment Successful!</CardTitle>
          <CardDescription>Your subscription has been activated.</CardDescription>
        </CardHeader>
        <CardFooter>
          <Button className="w-full" onClick={() => router.push('/dashboard')}>
            Go to Dashboard
          </Button>
        </CardFooter>
      </Card>
    );
  }

  return null;
} 