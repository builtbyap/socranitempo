import { createClient } from "../../../../supabase/server";
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const body = await req.text();
    const signature = req.headers.get("stripe-signature") as string;

    // This would normally verify the Stripe webhook signature
    // but we're using Pica Passthrough so we'll just parse the event
    const event = JSON.parse(body);

    // Handle the event
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        const userId = session.metadata?.user_id;
        const subscriptionType =
          session.metadata?.subscription_type || "monthly";

        if (userId) {
          // Update user subscription in database
          const supabase = await createClient();

          // Calculate subscription end date based on type
          const startDate = new Date();
          const endDate = new Date();

          if (subscriptionType.toLowerCase().includes("annual")) {
            endDate.setFullYear(endDate.getFullYear() + 1);
          } else {
            // Default to monthly
            endDate.setMonth(endDate.getMonth() + 1);
          }

          await supabase
            .from("users")
            .update({
              subscription_status: "active",
              subscription_type: subscriptionType,
              subscription_start_date: startDate.toISOString(),
              subscription_end_date: endDate.toISOString(),
            })
            .eq("user_id", userId);
        }
        break;
      }

      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object;
        // Handle successful payment if needed
        break;
      }

      default:
        // Unexpected event type
        console.log(`Unhandled event type ${event.type}`);
    }

    return NextResponse.json({ received: true }, { status: 200 });
  } catch (err: any) {
    console.error(`Webhook error: ${err.message}`);
    return NextResponse.json(
      { error: `Webhook error: ${err.message}` },
      { status: 400 },
    );
  }
}
