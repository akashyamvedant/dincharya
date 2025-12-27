// ============================================
// PAYMENT VERIFICATION EDGE FUNCTION
// ============================================
// Deploy: supabase functions deploy verify-payment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    const { order_id, payment_id, signature, amount, plan_id, plan_name } = await req.json()

    if (!order_id || !payment_id || !signature || !amount || !plan_id) {
      throw new Error('Missing required fields')
    }

    await supabase.from('payment_audit_log').insert({
      user_id: user.id,
      event_type: 'payment_initiated',
      razorpay_payment_id: payment_id,
      razorpay_order_id: order_id,
      amount: amount,
      status: 'verifying',
      metadata: { plan_id, plan_name }
    })

    const generatedSignature = await generateSignature(order_id, payment_id)
    
    if (generatedSignature !== signature) {
      await supabase.from('payment_audit_log').insert({
        user_id: user.id,
        event_type: 'signature_failed',
        razorpay_payment_id: payment_id,
        razorpay_order_id: order_id,
        amount: amount,
        status: 'failed',
        error_message: 'Signature verification failed',
        metadata: { expected: generatedSignature, received: signature }
      })

      return new Response(
        JSON.stringify({ success: false, error: 'Payment verification failed' }),
        { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    const planDurations: Record<string, number> = {
      'monthly': 30,
      'quarterly': 90,
      'yearly': 365
    }
    const durationDays = planDurations[plan_id] || 30
    const expiresAt = new Date()
    expiresAt.setDate(expiresAt.getDate() + durationDays)

    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: user.id,
        plan_id: plan_id,
        plan_name: plan_name,
        status: 'active',
        razorpay_payment_id: payment_id,
        razorpay_order_id: order_id,
        razorpay_signature: signature,
        amount: amount,
        started_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString()
      })
      .select()
      .single()

    if (subError) {
      throw subError
    }

    await supabase.from('payment_audit_log').insert({
      user_id: user.id,
      event_type: 'payment_success',
      razorpay_payment_id: payment_id,
      razorpay_order_id: order_id,
      amount: amount,
      status: 'success',
      metadata: { subscription_id: subscription.id, plan_id, expires_at: expiresAt }
    })

    return new Response(
      JSON.stringify({
        success: true,
        subscription: {
          id: subscription.id,
          plan_name: plan_name,
          expires_at: expiresAt.toISOString(),
          status: 'active'
        }
      }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )

  } catch (error) {
    console.error('Payment verification error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})

async function generateSignature(orderId: string, paymentId: string): Promise<string> {
  const message = `${orderId}|${paymentId}`
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(RAZORPAY_KEY_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  )
  
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message)
  )
  
  return Array.from(new Uint8Array(signature))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}
