"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

export async function signUp(email: string, password: string, fullName?: string) {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName || "",
      },
      emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"}/auth/callback`,
    },
  });

  if (error) {
    let errorMessage = "Failed to sign up";
    
    switch (error.message) {
      case "User already registered":
        errorMessage = "An account with this email already exists";
        break;
      case "Invalid email":
        errorMessage = "Invalid email address";
        break;
      case "Password should be at least 6 characters":
        errorMessage = "Password must be at least 6 characters";
        break;
    }
    
    return { success: false, error: errorMessage };
  }

  return { success: true, user: data.user };
}

export async function signIn(email: string, password: string) {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    let errorMessage = "Failed to sign in";
    
    switch (error.message) {
      case "Invalid login credentials":
        errorMessage = "Invalid email or password";
        break;
      case "Email not confirmed":
        errorMessage = "Please verify your email address";
        break;
      case "Invalid email":
        errorMessage = "Invalid email address";
        break;
    }
    
    return { success: false, error: errorMessage };
  }

  return { success: true, user: data.user };
}

export async function signOut() {
  const supabase = await createClient();
  const { error } = await supabase.auth.signOut();

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath("/", "layout");
  return { success: true };
}

export async function getUser() {
  const supabase = await createClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  
  if (error) {
    return { user: null, error };
  }
  
  return { user, error: null };
}

