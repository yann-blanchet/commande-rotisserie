import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || ''

interface EmailRequest {
    email: string
    code: string
}

serve(async (req) => {
    try {
        // Handle CORS preflight
        if (req.method === 'OPTIONS') {
            return new Response(null, {
                status: 204,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
                },
            })
        }

        // Parse request body
        let requestBody
        try {
            const bodyText = await req.text()
            requestBody = bodyText ? JSON.parse(bodyText) : {}
        } catch (parseError) {
            return new Response(
                JSON.stringify({ error: 'Invalid JSON in request body' }),
                { status: 400, headers: { 'Content-Type': 'application/json' } }
            )
        }

        const { email, code }: EmailRequest = requestBody

        if (!email || !code) {
            return new Response(
                JSON.stringify({ error: 'Email and code are required' }),
                { status: 400, headers: { 'Content-Type': 'application/json' } }
            )
        }

        // Option 1: Use Resend (recommended)
        if (RESEND_API_KEY) {
            const resendResponse = await fetch('https://api.resend.com/emails', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${RESEND_API_KEY}`,
                },
                body: JSON.stringify({
                    from: 'Commande Rotisserie <onboarding@resend.dev>', // Changez pour votre domaine en production
                    to: [email],
                    subject: 'Votre code OTP - Commande Rotisserie',
                    html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ff6b35;">🍗 Code OTP - Commande Rotisserie</h2>
              <p>Votre code de connexion est :</p>
              <div style="background: #f5f5f5; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 20px 0; border-radius: 8px;">
                ${code}
              </div>
              <p>Ce code est valide pendant <strong>10 minutes</strong>.</p>
              <p style="color: #666; font-size: 12px;">Si vous n'avez pas demandé ce code, ignorez cet email.</p>
            </div>
          `,
                }),
            })

            if (!resendResponse.ok) {
                const errorText = await resendResponse.text()
                console.error('Resend API error:', resendResponse.status, errorText)
                throw new Error(`Resend error (${resendResponse.status}): ${errorText}`)
            }

            // Try to parse response, but handle empty responses
            let responseData
            try {
                const responseText = await resendResponse.text()
                responseData = responseText ? JSON.parse(responseText) : {}
            } catch (parseError) {
                // If response is empty or invalid JSON, that's okay - Resend sometimes returns empty body on success
                console.log('Resend response parsed (or empty):', parseError)
                responseData = {}
            }

            return new Response(
                JSON.stringify({ success: true, message: 'Email sent via Resend', data: responseData }),
                {
                    status: 200,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Methods': 'POST',
                        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
                    }
                }
            )
        }

        // Option 2: Fallback if Resend is not configured
        // ⚠️ This should only be used for development/testing
        // In production, always configure RESEND_API_KEY

        // Log for debugging (only in development)
        console.log(`OTP Code for ${email}: ${code}`)

        // Return error if Resend is not configured (production mode)
        // Uncomment the code return below ONLY for development/testing
        const isDevelopment = Deno.env.get('ENVIRONMENT') === 'development'

        if (isDevelopment) {
            // ⚠️ DEVELOPMENT ONLY: Return code in response
            return new Response(
                JSON.stringify({
                    success: true,
                    message: 'Email service not configured - Code returned for development',
                    code: code // ⚠️ Remove this in production!
                }),
                {
                    status: 200,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                    }
                }
            )
        } else {
            // Production: Don't return the code
            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'Email service not configured. Please set RESEND_API_KEY environment variable.'
                }),
                {
                    status: 500,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                    }
                }
            )
        }
    } catch (error: any) {
        console.error('Error sending email:', error)
        return new Response(
            JSON.stringify({ error: error?.message || 'Unknown error occurred' }),
            {
                status: 500,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                }
            }
        )
    }
})

