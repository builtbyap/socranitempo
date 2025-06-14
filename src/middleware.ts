import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { auth } from "@/lib/firebase";

export function middleware(req: NextRequest) {
  const url = req.nextUrl.clone();

  // Check for Firebase auth token
  const authToken = req.cookies.get("__session")?.value;
  
  // Protected routes that require authentication
  if (url.pathname.startsWith("/dashboard") && !authToken) {
    url.pathname = "/sign-in";
    return NextResponse.redirect(url);
  }

  // Redirect authenticated users away from auth pages
  if ((url.pathname === "/sign-in" || url.pathname === "/sign-up") && authToken) {
    url.pathname = "/dashboard";
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

// Configure which routes to run middleware on
export const config = {
  matcher: ["/dashboard/:path*", "/sign-in", "/sign-up"]
};
