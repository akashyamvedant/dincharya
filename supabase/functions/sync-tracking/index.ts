// ============================================
// TRACKING DATA SYNC EDGE FUNCTION
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET',
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

    if (req.method === 'POST') {
      const { tracking_history } = await req.json()

      if (!Array.isArray(tracking_history)) {
        throw new Error('tracking_history must be an array')
      }

      const trackingRecords = tracking_history.map((entry: any) => ({
        user_id: user.id,
        activity_name: entry.activity,
        completed: entry.completed,
        completed_at: entry.completedAt || null,
        reason: entry.reason || null,
        notes: entry.notes || null,
        tracking_date: entry.date,
        synced_at: new Date().toISOString()
      }))

      const { data, error } = await supabase
        .from('routine_tracking')
        .upsert(trackingRecords, { 
          onConflict: 'user_id,activity_name,tracking_date' 
        })

      if (error) {
        throw error
      }

      return new Response(
        JSON.stringify({
          success: true,
          synced_count: trackingRecords.length
        }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    if (req.method === 'GET') {
      const url = new URL(req.url)
      const days = parseInt(url.searchParams.get('days') || '30')

      const fromDate = new Date()
      fromDate.setDate(fromDate.getDate() - days)

      const { data, error } = await supabase
        .from('routine_tracking')
        .select('*')
        .eq('user_id', user.id)
        .gte('tracking_date', fromDate.toISOString().split('T')[0])
        .order('tracking_date', { ascending: false })

      if (error) {
        throw error
      }

      return new Response(
        JSON.stringify({
          success: true,
          tracking_history: data
        }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

  } catch (error) {
    console.error('Tracking sync error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})
