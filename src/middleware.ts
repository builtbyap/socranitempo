import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  try {
    const res = NextResponse.next()
    const supabase = createMiddlewareClient({ req: request, res })

    // Refresh session if expired
    const {
      data: { session },
    } = await supabase.auth.getSession()

    // Check if the request is for the dashboard
    if (request.nextUrl.pathname.startsWith("/dashboard")) {
      if (!session) {
        // Redirect to sign-in if no session
        const redirectUrl = new URL("/sign-in", request.url)
        redirectUrl.searchParams.set("redirectTo", request.nextUrl.pathname)
        return NextResponse.redirect(redirectUrl)
      }

      // Check subscription status
      const { data: user } = await supabase
        .from("subs")
        .select("subscription_status, subscription_end_date")
        .eq("id", session.user.id)
        .single()

      if (!user || user.subscription_status !== "active" || new Date(user.subscription_end_date) < new Date()) {
        // Redirect to pricing if no active subscription
        return NextResponse.redirect(new URL("/pricing", request.url))
      }
    }

    // Check if the request is for auth pages
    if (request.nextUrl.pathname.startsWith("/sign-in") || 
        request.nextUrl.pathname.startsWith("/sign-up") ||
        request.nextUrl.pathname.startsWith("/forgot-password")) {
      if (session) {
        // Redirect to dashboard if already signed in
        return NextResponse.redirect(new URL("/dashboard", request.url))
      }
    }

    return res
  } catch (error) {
    console.error('Middleware error:', error)
    // In case of error, allow the request to proceed
    return NextResponse.next()
  }
}

// Ensure the middleware is only called for relevant paths
export const config = {
  matcher: [
    "/dashboard/:path*",
    "/sign-in",
    "/sign-up",
    "/forgot-password",
    "/reset-password",
  ],
}
