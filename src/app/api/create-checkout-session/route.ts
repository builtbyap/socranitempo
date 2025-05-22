import { NextRequest, NextResponse } from "next/server";
import { createCheckoutSession } from "@/lib/firebase";

export async function POST(req: NextRequest) {
  try {
    const { priceId } = await req.json();

    if (!priceId) {
      return NextResponse.json(
        { error: "Price ID is required" },
        { status: 400 }
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
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
} 