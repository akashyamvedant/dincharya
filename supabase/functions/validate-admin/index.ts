// ============================================
// ADMIN VALIDATION EDGE FUNCTION
// ============================================
// Deploy: supabase functions deploy validate-admin

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST',
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

    // Check if user has admin role
    const { data: adminRole } = await supabase
      .from('admin_roles')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle()

    const isAdmin = adminRole !== null

    if (req.method === 'GET') {
      // Just check admin status
      return new Response(
        JSON.stringify({
          is_admin: isAdmin,
          role: adminRole?.role || null
        }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    if (req.method === 'POST') {
      // Update admin settings (only if admin)
      if (!isAdmin) {
        return new Response(
          JSON.stringify({ success: false, error: 'Unauthorized: Admin access required' }),
          { status: 403, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
        )
      }

      const { settings } = await req.json()
      
      // Update admin_settings table
      const { data, error } = await supabase
        .from('admin_settings')
        .upsert({
          id: 1, // Single row for global settings
          ...settings,
          updated_by: user.id,
          updated_at: new Date().toISOString()
        })

      if (error) {
        throw error
      }

      return new Response(
        JSON.stringify({ success: true, settings: data }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

  } catch (error) {
    console.error('Admin validation error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})
