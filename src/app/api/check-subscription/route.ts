export const dynamic = 'force-dynamic';

import { NextResponse } from "next/server";
import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs";
import { cookies } from "next/headers";

export async function GET(request: Request) {
  try {
    const supabase = createRouteHandlerClient({ cookies });
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { data: subscription, error: subscriptionError } = await supabase
      .from("subscriptions")
      .select("*")
      .eq("user_id", user.id)
      .single();

    if (subscriptionError) {
      return NextResponse.json({ error: "Failed to fetch subscription" }, { status: 500 });
    }

    return NextResponse.json({ subscription });
  } catch (error) {
    console.error("Error in check-subscription route:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
} 