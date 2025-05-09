import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(req: NextRequest) {
  try {
    const res = NextResponse.next()
    const supabase = createMiddlewareClient({ req, res })

    // Check if we have a session
    const {
      data: { session },
    } = await supabase.auth.getSession()

    // Get the pathname of the request
    const path = req.nextUrl.pathname

    // If the user is not signed in and the current path is not /sign-in or /sign-up,
    // redirect the user to /sign-in
    if (!session && path !== '/sign-in' && path !== '/sign-up') {
      const redirectUrl = new URL('/sign-in', req.url)
      return NextResponse.redirect(redirectUrl)
    }

    // If the user is signed in and the current path is /sign-in or /sign-up,
    // redirect the user to /
    if (session && (path === '/sign-in' || path === '/sign-up')) {
      const redirectUrl = new URL('/', req.url)
      return NextResponse.redirect(redirectUrl)
    }

    // If accessing dashboard, check subscription status
    if (path.startsWith('/dashboard')) {
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
  } catch (error) {
    console.error('Middleware error:', error)
    // In case of error, redirect to sign-in page
    const redirectUrl = new URL('/sign-in', req.url)
    return NextResponse.redirect(redirectUrl)
  }
}

// Ensure the middleware is only called for relevant paths
export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
}
