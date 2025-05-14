// Verify Payment Status Edge Function

Deno.serve(async (req) => {
  // Handle OPTIONS request for CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
      status: 200,
    });
  }

  try {
    const { payment_intent_id, client_secret, user_id } = await req.json();

    // Validate required parameters
    if (!payment_intent_id || !client_secret || !user_id) {
      throw new Error(
        "Missing required parameters: payment_intent_id, client_secret, and user_id are required",
      );
    }

    // Retrieve payment intent status using Pica Passthrough
    const url = `https://api.picaos.com/v1/passthrough/payment_intents/${payment_intent_id}?client_secret=${client_secret}`;

    const response = await fetch(url, {
      method: "GET",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "x-pica-secret": Deno.env.get("PICA_SECRET_KEY") || "",
        "x-pica-connection-key":
          Deno.env.get("PICA_STRIPE_CONNECTION_KEY") || "",
        "x-pica-action-id": "conn_mod_def::GCmLP3yB4Mg::rCRiTSApTyy-gb44BkTwPw",
      },
    });

    const paymentData = await response.json();

    if (!response.ok) {
      throw new Error(
        `Stripe API error: ${paymentData.error?.message || response.statusText}`,
      );
    }

    // If payment is successful, update user subscription status
    if (paymentData.status === "succeeded") {
      // Create Supabase client
      const { createClient } = await import(
        "https://esm.sh/@supabase/supabase-js@2"
      );

      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_KEY");

      if (!supabaseUrl || !supabaseKey) {
        throw new Error("Missing Supabase credentials");
      }

      const supabase = createClient(supabaseUrl, supabaseKey);

      // Calculate subscription duration based on metadata
      const subscriptionType =
        paymentData.metadata?.subscription_type || "monthly";
      const durationMonths = subscriptionType === "annual" ? 12 : 1;

      // Update user subscription in database
      const startDate = new Date();
      const endDate = new Date();
      endDate.setMonth(endDate.getMonth() + durationMonths);

      const { error: updateError } = await supabase
        .from("users")
        .update({
          subscription_type: subscriptionType,
          subscription_status: "active",
          subscription_start_date: startDate.toISOString(),
          subscription_end_date: endDate.toISOString(),
        })
        .eq("user_id", user_id);

      if (updateError) {
        throw new Error(`Error updating subscription: ${updateError.message}`);
      }
    }

    return new Response(
      JSON.stringify({
        status: paymentData.status,
        payment_intent: paymentData.id,
        amount_received: paymentData.amount_received,
        subscription_updated: paymentData.status === "succeeded",
      }),
      {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Content-Type": "application/json",
        },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      status: 400,
    });
  }
});
