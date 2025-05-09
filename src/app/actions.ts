"use server";

import { encodedRedirect } from "@/utils/utils";
import { headers, cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "../../supabase/server";

export const signUpAction = async (formData: FormData) => {
  const email = formData.get("email")?.toString();
  const password = formData.get("password")?.toString();
  const fullName = formData.get("full_name")?.toString() || '';
  const supabase = await createClient();
  const origin = headers().get("origin");

  if (!email || !password) {
    return encodedRedirect(
      "error",
      "/sign-up",
      "Email and password are required",
    );
  }

  const { data: { user }, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: `${origin}/auth/callback`,
      data: {
        full_name: fullName,
        email: email,
      }
    },
  });

  console.log("After signUp", error);

  if (error) {
    console.error(error.code + " " + error.message);
    return encodedRedirect("error", "/sign-up", error.message);
  }

  if (user) {
    try {
      const { error: updateError } = await supabase
        .from('users')
        .insert({
          id: user.id,
          name: fullName,
          full_name: fullName,
          email: email,
          user_id: user.id,
          token_identifier: user.id,
          created_at: new Date().toISOString(),
          subscription_status: 'pending', // Set initial subscription status
          subscription_end_date: null
        });

      if (updateError) {
        console.error('Error updating user profile:', updateError);
      }
    } catch (err) {
      console.error('Error in user profile creation:', err);
    }
  }

  // Redirect to pricing page with a success message
  return encodedRedirect(
    "success",
    "/pricing",
    "Thanks for signing up! Please choose a subscription plan to continue.",
  );
};

export const signInAction = async (formData: FormData) => {
  const email = formData.get("email") as string;
  const password = formData.get("password") as string;
  const supabase = await createClient();

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    return encodedRedirect("error", "/sign-in", error.message);
  }

  return redirect("/dashboard");
};

export const forgotPasswordAction = async (formData: FormData) => {
  const email = formData.get("email")?.toString();
  const supabase = await createClient();
  const origin = headers().get("origin");
  const callbackUrl = formData.get("callbackUrl")?.toString();

  if (!email) {
    return encodedRedirect("error", "/forgot-password", "Email is required");
  }

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${origin}/auth/callback?redirect_to=/protected/reset-password`,
  });

  if (error) {
    console.error(error.message);
    return encodedRedirect(
      "error",
      "/forgot-password",
      "Could not reset password",
    );
  }

  if (callbackUrl) {
    return redirect(callbackUrl);
  }

  return encodedRedirect(
    "success",
    "/forgot-password",
    "Check your email for a link to reset your password.",
  );
};

export const resetPasswordAction = async (formData: FormData) => {
  const supabase = await createClient();

  const password = formData.get("password") as string;
  const confirmPassword = formData.get("confirmPassword") as string;

  if (!password || !confirmPassword) {
    encodedRedirect(
      "error",
      "/protected/reset-password",
      "Password and confirm password are required",
    );
  }

  if (password !== confirmPassword) {
    encodedRedirect(
      "error",
      "/dashboard/reset-password",
      "Passwords do not match",
    );
  }

  const { error } = await supabase.auth.updateUser({
    password: password,
  });

  if (error) {
    encodedRedirect(
      "error",
      "/dashboard/reset-password",
      "Password update failed",
    );
  }

  encodedRedirect("success", "/protected/reset-password", "Password updated");
};

export const signOutAction = async () => {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return redirect("/sign-in");
};

export async function getSession() {
  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}

export async function getUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
}

export const googleSignInAction = async (idToken: string) => {
  const supabase = await createClient();
  const origin = headers().get("origin");

  const { data, error } = await supabase.auth.signInWithIdToken({
    provider: 'google',
    token: idToken,
  });

  if (error) {
    console.error("Google sign in error:", error);
    return encodedRedirect("error", "/sign-in", error.message);
  }

  if (data.user) {
    try {
      // Check if user exists in the users table
      const { data: existingUser } = await supabase
        .from('users')
        .select('*')
        .eq('user_id', data.user.id)
        .single();

      if (!existingUser) {
        // Create user profile if it doesn't exist
        const { error: updateError } = await supabase
          .from('users')
          .insert({
            id: data.user.id,
            name: data.user.user_metadata.full_name || data.user.email?.split('@')[0],
            full_name: data.user.user_metadata.full_name,
            email: data.user.email,
            user_id: data.user.id,
            token_identifier: data.user.id,
            created_at: new Date().toISOString(),
            subscription_status: 'pending', // Set initial subscription status
            subscription_end_date: null
          });

        if (updateError) {
          console.error('Error creating user profile:', updateError);
        }

        // If this is a new user, redirect to pricing page
        return encodedRedirect(
          "success",
          "/pricing",
          "Welcome! Please choose a subscription plan to continue."
        );
      }

      // If user exists, check their subscription status
      if (existingUser.subscription_status === 'cancelled' || !existingUser.subscription_status) {
        return encodedRedirect(
          "success",
          "/pricing",
          "Please choose a subscription plan to continue."
        );
      }
    } catch (err) {
      console.error('Error in user profile creation:', err);
    }
  }

  // If user has an active subscription, redirect to dashboard
  return redirect("/dashboard");
};

export async function cancelSubscriptionAction() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Not authenticated" };
  }

  try {
    // Update the user's subscription status in the database
    const { error } = await supabase
      .from('users')
      .update({ 
        subscription_status: 'cancelled',
        subscription_end_date: new Date().toISOString() // Immediately revoke access
      })
      .eq('id', user.id);

    if (error) throw error;

    return { success: true };
  } catch (error) {
    console.error('Error cancelling subscription:', error);
    return { error: "Failed to cancel subscription" };
  }
}