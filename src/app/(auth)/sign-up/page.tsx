"use client";

import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import Link from 'next/link';
import Navbar from '@/components/navbar';

function SignUpForm() {
  const router = useRouter();

  const handleSignUp = () => {
    router.push('/dashboard');
  };

  return (
    <Card className="w-[350px]">
      <CardHeader>
        <CardTitle>Sign Up</CardTitle>
        <CardDescription>Click the button below to access your dashboard</CardDescription>
      </CardHeader>
      <CardContent>
        <Button 
          onClick={handleSignUp} 
          className="w-full"
        >
          Go to Dashboard
        </Button>
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
