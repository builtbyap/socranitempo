import { createClient } from "../../../../supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const redirect_to = requestUrl.searchParams.get("redirect_to");

  if (code) {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);

    if (data?.user) {
      // Check if this is a new user (email verification after signup)
      const { data: userData } = await supabase
        .from("users")
        .select("subscription_status")
        .eq("user_id", data.user.id)
        .single();

      // If user has no subscription or inactive subscription, redirect to pricing
      if (
        !userData?.subscription_status ||
        userData.subscription_status !== "active"
      ) {
        // Always redirect new users to pricing after email verification
        if (redirect_to?.includes("/pricing")) {
          return NextResponse.redirect(new URL("/pricing", requestUrl.origin));
        }

        // If no specific redirect is requested, send to pricing
        if (!redirect_to) {
          return NextResponse.redirect(new URL("/pricing", requestUrl.origin));
        }
      }
    }
  }

  // URL to redirect to after sign in process completes
  const redirectTo = redirect_to || "/dashboard";
  return NextResponse.redirect(new URL(redirectTo, requestUrl.origin));
}
