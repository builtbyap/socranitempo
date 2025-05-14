// Create Checkout Session Edge Function

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
    const {
      price,
      quantity,
      subscription_type,
      success_url,
      cancel_url,
      customer_email,
      user_id,
    } = await req.json();

    // Validate required parameters
    if (!price || !success_url || !cancel_url) {
      throw new Error(
        "Missing required parameters: price, success_url, and cancel_url are required",
      );
    }

    // Create checkout session using Pica Passthrough
    const url = "https://api.picaos.com/v1/passthrough/v1/checkout/sessions";
    const body = new URLSearchParams();

    body.append("mode", "payment");
    body.append("success_url", success_url);
    body.append("cancel_url", cancel_url);
    body.append("automatic_tax[enabled]", "true");

    // Add line items
    body.append("line_items[0][price_data][currency]", "usd");
    body.append(
      "line_items[0][price_data][product_data][name]",
      `${subscription_type || "Standard"} Subscription`,
    );
    body.append("line_items[0][price_data][unit_amount]", price.toString());
    body.append("line_items[0][quantity]", quantity.toString() || "1");

    // Add customer email if provided
    if (customer_email) {
      body.append("customer_email", customer_email);
    }

    // Add metadata for tracking
    if (user_id) {
      body.append("metadata[user_id]", user_id);
    }
    body.append("metadata[subscription_type]", subscription_type || "standard");

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "x-pica-secret": Deno.env.get("PICA_SECRET_KEY") || "",
        "x-pica-connection-key":
          Deno.env.get("PICA_STRIPE_CONNECTION_KEY") || "",
        "x-pica-action-id": "conn_mod_def::GCmLNSLWawg::Pj6pgAmnQhuqMPzB8fquRg",
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
