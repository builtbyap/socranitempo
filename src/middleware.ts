import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req, res })

  // Check if we have a session
  const {
    data: { session },
  } = await supabase.auth.getSession()

  // If no session, redirect to sign-in
  if (!session) {
    return NextResponse.redirect(new URL('/sign-in', req.url))
  }

  // If accessing dashboard, check subscription status
  if (req.nextUrl.pathname.startsWith('/dashboard')) {
    const { data: user } = await supabase
      .from('users')
      .select('subscription_status, subscription_end_date')
      .eq('id', session.user.id)
      .single()

    const isSubscribed = 
      user?.subscription_status === 'active' && 
      user?.subscription_end_date && 
      new Date(user.subscription_end_date) > new Date()

    if (!isSubscribed) {
      return NextResponse.redirect(new URL('/pricing', req.url))
    }
  }

  return res
}

// Ensure the middleware is only called for relevant paths
export const config = {
  matcher: ['/dashboard/:path*'],
}
