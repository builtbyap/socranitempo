"use server";

import { encodedRedirect } from "@/utils/utils";
import { redirect } from "next/navigation";
import { signIn, signUp } from "@/lib/firebase";

export const signUpAction = async (formData: FormData) => {
  const email = formData.get("email")?.toString();
  const password = formData.get("password")?.toString();
  const fullName = formData.get("full_name")?.toString() || "";

  if (!email || !password) {
    return encodedRedirect(
      "error",
      "/sign-up",
      "Email and password are required",
    );
  }

  const { success, error, user } = await signUp(email, password);

  if (!success || error) {
    console.error("Sign up error:", error);
    return encodedRedirect("error", "/sign-up", error || "Failed to sign up");
  }

  if (user) {
    // Redirect to payment page for new users
    return redirect("/payment");
  }

  return redirect("/sign-up");
};

export const signInAction = async (formData: FormData) => {
  const email = formData.get("email") as string;
  const password = formData.get("password") as string;

  const { success, error, subscription } = await signIn(email, password);

  if (!success || error) {
    return encodedRedirect("error", "/sign-in", error || "Failed to sign in");
  }

  // If user has no subscription, redirect to payment page
  if (!subscription) {
    return redirect("/payment");
  }

  // If user has an active subscription, redirect to dashboard
  return redirect("/dashboard");
};

export const signOutAction = async () => {
  const { logOut } = await import("@/lib/firebase");
  await logOut();
  return redirect("/sign-in");
};
