// Create Payment Intent Edge Function

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
    const { amount, currency, description, customer_email, subscription_type } =
      await req.json();

    // Validate required parameters
    if (!amount || !currency) {
      throw new Error(
        "Missing required parameters: amount and currency are required",
      );
    }

    // Create payment intent using Pica Passthrough
    const url = "https://api.picaos.com/v1/passthrough/payment_intents";
    const body = new URLSearchParams({
      amount: amount.toString(),
      currency: currency.toLowerCase(),
      "automatic_payment_methods[enabled]": "true",
      description:
        description || `${subscription_type || "Standard"} Subscription`,
      receipt_email: customer_email || "",
    });

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "x-pica-secret": Deno.env.get("PICA_SECRET_KEY") || "",
        "x-pica-connection-key":
          Deno.env.get("PICA_STRIPE_CONNECTION_KEY") || "",
        "x-pica-action-id": "conn_mod_def::GCmOAuPP5MQ::O0MeKcobRza5lZQrIkoqBA",
      },
      body: body.toString(),
    });

    const responseData = await response.json();

    if (!response.ok) {
      throw new Error(
        `Stripe API error: ${responseData.error?.message || response.statusText}`,
      );
    }

    return new Response(JSON.stringify(responseData), {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      status: 200,
    });
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
