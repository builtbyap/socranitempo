'use strict';

/**
 * Superwall sends signed webhooks via Svix.
 * Verifies signatures, parses subscription events, updates public.users (service role).
 */

const express = require('express');
const { Webhook } = require('svix');
const { createClient } = require('@supabase/supabase-js');

const INACTIVE_MARKERS = [
  'expiration',
  'expire',
  'expired',
  'billing_issue',
  'refund',
  'paused',
];

function classifyEvent(rawName = '') {
  const name = String(rawName).replace(/-/g, '_').toLowerCase();
  for (const m of INACTIVE_MARKERS) {
    if (name.includes(m)) {
      return 'inactive';
    }
  }
  const looksUncanceled =
    name.includes('uncanceled') ||
    name.includes('uncancelled') ||
    name.includes('uncancellation');
  if (!looksUncanceled) {
    if (
      name.includes('cancellation') ||
      name.includes('_cancel') ||
      name.includes('cancel_') ||
      name.endsWith('canceled') ||
      name.endsWith('cancelled')
    ) {
      return 'cancellation';
    }
  }
  const ACTIVE_MARKERS = [
    'purchase',
    'renewal',
    'subscribe',
    'subscription',
    'trial',
    'intro',
    'reactivat',
    'uncancel',
  ];
  for (const m of ACTIVE_MARKERS) {
    if (name.includes(m)) {
      return 'active';
    }
  }
  return 'unknown';
}

function subscriptionLikePayload(data = {}) {
  return Boolean(
    data.productId ||
      data.product_id ||
      data.productIdentifier ||
      data.store_transaction_id ||
      data.transactionId ||
      data.transaction_id
  );
}

function deriveSubscriptionColumns(data, classification) {
  if (classification !== 'active') {
    return null;
  }
  const periodType = String(data.periodType || data.period_type || '').toUpperCase();
  const name = String(data.name || data.event_name || '').toLowerCase();
  const isTrialish =
    periodType === 'INTRO' ||
    periodType === 'TRIAL' ||
    name.includes('trial') ||
    String(data.offerType || '').toLowerCase() === 'introductory';

  const pid = (
    data.productId ||
    data.product_id ||
    data.productIdentifier ||
    ''
  )
    .toString()
    .trim();
  const typeSlug =
    pid || (isTrialish ? 'trial' : 'pro');

  let subscriptionStatus = 'active';
  if (isTrialish) {
    subscriptionStatus = 'trialing';
  }

  return {
    subscription_status: subscriptionStatus,
    subscription_type: typeSlug.toLowerCase() || 'pro',
    updated_at: new Date().toISOString(),
  };
}

function resolveUserUUID(originalAppUserId) {
  if (originalAppUserId == null) return null;
  const s = String(originalAppUserId).trim();
  if (!s || s.startsWith('$SuperwallAlias')) {
    return null;
  }
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(s) ? s.toLowerCase() : null;
}

/** Walk common Superwall / Svix nestings to get inner data + event name. */
function flattenWebhookBody(root) {
  if (!root || typeof root !== 'object') {
    return { raw: root, data: {}, eventName: '' };
  }
  const eventName =
    root.type ||
    root.event ||
    root.eventName ||
    root.name ||
    '';
  let data = root;
  if (root.data && typeof root.data === 'object') {
    data = root.data;
    if (data.data && typeof data.data === 'object') {
      data = data.data;
    }
  }
  const originalAppUserId =
    data.originalAppUserId ??
    data.original_app_user_id ??
    root.originalAppUserId ??
    '';

  return {
    raw: root,
    data:
      typeof data === 'object' && data !== null ? { ...data, originalAppUserId } : {},
    eventName:
      eventName ||
      data.name ||
      data.event_name ||
      '',
  };
}

function getSupabaseAdmin() {
  const url = process.env.SUPABASE_URL?.trim();
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !serviceKey) {
    return null;
  }
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function handleVerifiedPayload(parsed) {
  const supabase = getSupabaseAdmin();
  if (!supabase) {
    console.warn(
      'superwall webhook: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY — skip DB update'
    );
    return { ok: false, skipped: true, reason: 'no_supabase' };
  }

  const { data, eventName: flatEvent } = flattenWebhookBody(parsed);
  const eventNameRaw = flatEvent || data.name || data.event_name || '';
  let classification = classifyEvent(String(eventNameRaw));
  if (
    classification === 'unknown' &&
    subscriptionLikePayload(data)
  ) {
    classification = 'active';
  }
  if (classification === 'unknown') {
    return {
      ok: true,
      skipped: true,
      reason: 'ignored_event',
      eventName: eventNameRaw,
    };
  }

  let userId = resolveUserUUID(data.originalAppUserId);
  if (
    !userId &&
    data.user_attributes &&
    typeof data.user_attributes === 'object'
  ) {
    const aid =
      data.user_attributes.supabase_user_id ?? data.user_attributes.user_id;
    userId = resolveUserUUID(aid);
  }

  if (!userId) {
    console.warn(
      'superwall webhook: could not resolve Supabase UUID (originalAppUserId missing or alias). Event:',
      eventNameRaw
    );
    return {
      ok: true,
      skipped: true,
      reason: 'no_user_uuid',
      hint: 'Identify users with Supabase UUID via Superwall before purchase.',
    };
  }

  const nowIso = new Date().toISOString();

  if (classification === 'cancellation') {
    const patch = {
      subscription_status: 'canceled',
      subscription_type: 'free',
      updated_at: nowIso,
    };
    const { error } = await supabase.from('users').update(patch).eq('id', userId);
    if (error) {
      console.error('superwall webhook DB error (cancellation):', error);
      throw error;
    }
    return {
      ok: true,
      userId,
      subscription_status: patch.subscription_status,
      subscription_type: patch.subscription_type,
      eventName: eventNameRaw,
    };
  }

  if (classification === 'inactive') {
    const patch = {
      subscription_status: 'inactive',
      subscription_type: 'free',
      updated_at: nowIso,
    };
    const { error } = await supabase.from('users').update(patch).eq('id', userId);
    if (error) {
      console.error('superwall webhook DB error (inactive):', error);
      throw error;
    }
    return {
      ok: true,
      userId,
      subscription_status: patch.subscription_status,
      subscription_type: patch.subscription_type,
      eventName: eventNameRaw,
    };
  }

  const cols = deriveSubscriptionColumns(data, classification);
  if (!cols) {
    return { ok: true, skipped: true, reason: 'unhandled_active_shape', eventName: eventNameRaw };
  }

  const { error } = await supabase.from('users').update(cols).eq('id', userId);
  if (error) {
    console.error('superwall webhook DB error (active):', error);
    throw error;
  }

  return {
    ok: true,
    userId,
    subscription_status: cols.subscription_status,
    subscription_type: cols.subscription_type,
    eventName: eventNameRaw,
  };
}

/**
 * Registers POST /webhooks/superwall with raw JSON body — must mount BEFORE express.json().
 */
function mountSuperwallWebhook(app) {
  app.post(
    '/webhooks/superwall',
    express.raw({ type: 'application/json', limit: '512kb' }),
    async (req, res) => {
      const secret = process.env.SUPERWALL_WEBHOOK_SECRET?.trim();
      if (!secret) {
        console.error('SUPERWALL_WEBHOOK_SECRET not set');
        return res.status(503).send('Webhook not configured');
      }

      const svixHeaders = {
        'svix-id': req.get('svix-id'),
        'svix-timestamp': req.get('svix-timestamp'),
        'svix-signature': req.get('svix-signature'),
      };

      if (
        !svixHeaders['svix-id'] ||
        !svixHeaders['svix-timestamp'] ||
        !svixHeaders['svix-signature']
      ) {
        return res.status(400).send('Missing Svix headers');
      }

      const rawBuf =
        req.body instanceof Buffer ? req.body : Buffer.from(req.body ?? '', 'utf8');
      const payloadString = rawBuf.toString('utf8');

      let parsed;
      try {
        const wh = new Webhook(secret);
        parsed = wh.verify(payloadString, svixHeaders);
      } catch (e) {
        console.error('Svix verification failed:', e.message);
        return res.status(401).send('Invalid signature');
      }

      try {
        const result = await handleVerifiedPayload(parsed);
        return res.status(200).json({ received: true, ...result });
      } catch (e) {
        console.error('Webhook handler error:', e);
        return res.status(500).json({ error: e.message || String(e) });
      }
    }
  );
}

module.exports = { mountSuperwallWebhook };
