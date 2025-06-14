"use client";

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { onAuthStateChanged, User } from 'firebase/auth';
import { auth } from '@/lib/firebase/auth';
import { doc, onSnapshot, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase/db';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Loader2, CheckCircle2 } from "lucide-react";
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
  const [paymentSuccess, setPaymentSuccess] = useState(false);

  useEffect(() => {
    const processPayment = async () => {
      try {
        const sessionId = searchParams.get('session_id');
        if (!sessionId) {
          throw new Error('No session ID found');
        }

        const currentUser = auth.currentUser;
        if (!currentUser) {
          throw new Error('No authenticated user found');
        }

        const requestBody = {
          sessionId,
          userId: currentUser.uid
        };

        const response = await fetch('https://us-central1-socrani-18328.cloudfunctions.net/handleSuccessfulPayment', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify(requestBody),
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
          setPaymentSuccess(true);
          // Wait for 2 seconds to show success message before redirecting
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
          <CardDescription>There was an error processing your payment</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-red-600 mb-4">{error}</p>
          <Button 
            onClick={() => router.push('/pricing')}
            className="w-full"
          >
            Return to Pricing
          </Button>
        </CardContent>
      </Card>
    );
  }

  if (paymentSuccess) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle2 className="h-6 w-6 text-green-500" />
            Payment Successful
          </CardTitle>
          <CardDescription>Your subscription has been activated</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-green-600 mb-4">Redirecting to dashboard...</p>
        </CardContent>
      </Card>
    );
  }

  return null;
} 