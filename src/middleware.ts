import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { adminAuth, adminDb } from "@/lib/firebase-admin";

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const url = req.nextUrl.clone();

  // Check if the request is for the dashboard
  if (url.pathname.startsWith("/dashboard")) {
    try {
      // Get the Firebase ID token from the Authorization header
      const authHeader = req.headers.get("authorization");
      if (!authHeader?.startsWith("Bearer ")) {
        url.pathname = "/sign-in";
        return NextResponse.redirect(url);
      }

      const idToken = authHeader.split("Bearer ")[1];
      const decodedToken = await adminAuth.verifyIdToken(idToken);
      const userId = decodedToken.uid;

      // Don't redirect if coming from a successful payment
      const paymentParam = url.searchParams.get("payment");
      if (paymentParam === "success") {
        return res;
      }

      // Check subscription status in Firestore
      const customerDoc = await adminDb.collection("customers").doc(userId).get();
      
      if (!customerDoc.exists) {
        url.pathname = "/payment";
        return NextResponse.redirect(url);
      }

      const customerData = customerDoc.data();
      
      // Check if subscription is active and not expired
      if (!customerData?.subscriptionStatus || customerData.subscriptionStatus !== "active") {
        url.pathname = "/payment";
        return NextResponse.redirect(url);
      }

      // Check if subscription is expired
      const currentPeriodEnd = customerData.subscriptionEndDate?.toDate();
      if (currentPeriodEnd && currentPeriodEnd < new Date()) {
        url.pathname = "/payment";
        return NextResponse.redirect(url);
      }

      // If we get here, the user has an active subscription
      return res;
    } catch (err) {
      console.error("Error checking subscription status:", err);
      url.pathname = "/sign-in";
      return NextResponse.redirect(url);
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
