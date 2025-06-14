"use client";

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { onAuthStateChanged, User } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { doc, onSnapshot, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase/db';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Loader2, CheckCircle2, XCircle } from "lucide-react";
import { Suspense } from 'react';
import Link from 'next/link';
import { httpsCallable } from 'firebase/functions';
import { functions } from '@/lib/firebase';

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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const router = useRouter();

  // Handle authentication state
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setUser(user);
      if (!user) {
        console.log('No authenticated user found, redirecting to sign-in');
        router.push('/sign-in');
      }
    });

    return () => unsubscribe();
  }, [router]);

  // Process payment once we have an authenticated user
  useEffect(() => {
    async function processPayment() {
      if (!user) {
        return; // Wait for user to be authenticated
      }

      try {
        setLoading(true);
        setError(null);

        // Get session ID from URL
        const params = new URLSearchParams(window.location.search);
        const sessionId = params.get('session_id');

        if (!sessionId) {
          throw new Error('No session ID found');
        }

        console.log('Processing payment for user:', user.uid);

        // Process the payment
        const handlePayment = httpsCallable(functions, 'handleSuccessfulPayment');
        await handlePayment({ 
          sessionId,
          userId: user.uid
        });

        console.log('Payment processed successfully, redirecting to dashboard');
        router.push('/dashboard');
      } catch (error: any) {
        console.error('Error processing payment:', error);
        setError(error.message || 'Failed to process payment');
      } finally {
        setLoading(false);
      }
    }

    if (user) {
      processPayment();
    }
  }, [user, router]);

  if (loading) {
    return (
      <Card className="w-[350px]">
        <CardHeader>
          <CardTitle>Processing Payment</CardTitle>
          <CardDescription>Please wait while we confirm your subscription</CardDescription>
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
          <CardTitle className="flex items-center gap-2 text-red-600">
            <XCircle className="h-6 w-6" />
            Payment Error
          </CardTitle>
          <CardDescription>{error}</CardDescription>
        </CardHeader>
        <CardContent>
          <Button asChild className="w-full">
            <Link href="/pricing">Return to Pricing</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }

  return null;
} 