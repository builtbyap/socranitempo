import { NextResponse } from "next/server";
import { createClient } from "../../../../supabase/server";

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");

    if (!userId) {
      return NextResponse.json(
        { error: "User ID is required" },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    // Get user's subscription status from the database
    const { data: user, error } = await supabase
      .from("users")
      .select("subscription_status, subscription_end_date")
      .eq("id", userId)
      .single();

    if (error) {
      console.error("Error fetching subscription status:", error);
      return NextResponse.json(
        { error: "Failed to fetch subscription status" },
        { status: 500 }
      );
    }

    // Check if subscription is active
    const isSubscribed = 
      user.subscription_status === "active" && 
      user.subscription_end_date && 
      new Date(user.subscription_end_date) > new Date();

    return NextResponse.json({ isSubscribed });
  } catch (error) {
    console.error("Error in check-subscription route:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
} 