import { createServerClient } from "@supabase/ssr";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const url = req.nextUrl.clone();

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return req.cookies.getAll().map(({ name, value }) => ({
            name,
            value,
          }));
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            req.cookies.set(name, value);
            res.cookies.set(name, value, options);
          });
        },
      },
    },
  );

  // Refresh session if expired - required for Server Components
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();

  if (error) {
    console.error("Auth session error:", error);
  }

  // Check if the request is for the dashboard
  if (url.pathname.startsWith("/dashboard")) {
    // If no session, redirect to sign-in
    if (!session) {
      url.pathname = "/sign-in";
      return NextResponse.redirect(url);
    }

    // Check subscription status for authenticated users
    try {
      const { data: userData } = await supabase
        .from("users")
        .select("subscription_status")
        .eq("user_id", session.user.id)
        .single();

      // If user doesn't have an active subscription, redirect to pricing page
      if (!userData || userData.subscription_status !== "active") {
        url.pathname = "/payment";
        return NextResponse.redirect(url);
      }
    } catch (err) {
      console.error("Error checking subscription status:", err);
    }
  }

  return res;
}

// Ensure the middleware is only called for relevant paths
export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public (public files)
     */
    "/((?!_next/static|_next/image|favicon.ico|public|api).*)",
  ],
};
