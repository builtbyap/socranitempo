"use client";

import { FormMessage, Message } from "@/components/form-message";
import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import Link from "next/link";
import { signUpAction } from "@/app/actions";
import { GoogleSignInButton } from "@/components/google-sign-in-button";

interface SignUpFormProps {
  message?: Message;
}

export function SignUpForm({ message }: SignUpFormProps) {
  return (
    <form className="flex flex-col space-y-6">
      <div className="space-y-2 text-center">
        <h1 className="text-3xl font-semibold tracking-tight">Sign up</h1>
        <p className="text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link
            className="text-primary font-medium hover:underline transition-all"
            href="/sign-in"
          >
            Sign in
          </Link>
        </p>
      </div>

      <div className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="full_name" className="text-sm font-medium">
            Full Name
          </Label>
          <Input
            id="full_name"
            name="full_name"
            type="text"
            placeholder="John Doe"
            required
            className="w-full"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="email" className="text-sm font-medium">
            Email
          </Label>
          <Input
            id="email"
            name="email"
            type="email"
            placeholder="you@example.com"
            required
            className="w-full"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="password" className="text-sm font-medium">
            Password
          </Label>
          <Input
            id="password"
            type="password"
            name="password"
            placeholder="Your password"
            minLength={6}
            required
            className="w-full"
          />
        </div>
      </div>

      <SubmitButton
        formAction={signUpAction}
        pendingText="Signing up..."
        className="w-full"
      >
        Sign up
      </SubmitButton>

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
        <div className="relative flex justify-center text-xs uppercase">
          <span className="bg-card px-2 text-muted-foreground">
            Or continue with
          </span>
        </div>
      </div>

      <GoogleSignInButton />

      {message && <FormMessage message={message} />}
    </form>
  );
} 