import { NextRequest, NextResponse } from "next/server";
import { createCheckoutSession } from "@/lib/firebase";
import { auth } from "@/lib/firebase";
import { corsMiddleware, corsOptionsMiddleware } from "@/lib/cors";

export async function POST(req: NextRequest) {
  try {
    // Apply CORS middleware
    const corsResponse = corsMiddleware(req);
    if (corsResponse.status !== 200) {
      return corsResponse;
    }

    const { priceId } = await req.json();

    if (!priceId) {
      return NextResponse.json(
        { error: "Price ID is required" },
        { status: 400 }
      );
    }

    // Get the current user
    const user = auth.currentUser;
    if (!user) {
      return NextResponse.json(
        { error: "User must be authenticated" },
        { status: 401 }
      );
    }

    const { success, sessionId, error } = await createCheckoutSession(priceId);

    if (!success || !sessionId) {
      return NextResponse.json(
        { error: error?.toString() || "Failed to create checkout session" },
        { status: 400 }
      );
    }

    return NextResponse.json({ sessionId });
  } catch (error: any) {
    console.error("Error creating checkout session:", error);
    return NextResponse.json(
      { error: error.message || "Internal server error" },
      { status: 500 }
    );
  }
}

// Handle CORS preflight requests
export async function OPTIONS(req: NextRequest) {
  return corsOptionsMiddleware(req);
} 