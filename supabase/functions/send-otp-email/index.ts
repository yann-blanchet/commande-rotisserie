import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || ''

interface EmailRequest {
    email: string
    code: string
}

// Helper function to create a success response
function createResponse(success: boolean, message: string, code: string, email: string, error?: string) {
    return new Response(
        JSON.stringify({
            success,
            message,
            error: error || undefined,
            code,
            email
        }),
        {
            status: 200, // Always return 200
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
            }
        }
    )
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response(null, {
            status: 204,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
            },
        })
    }

    let email = ''
    let code = ''

    try {
        // Parse request body
        const bodyText = await req.text()
        const requestBody: EmailRequest = bodyText ? JSON.parse(bodyText) : {}
        email = (requestBody.email || '').trim()
        code = (requestBody.code || '').trim()

        if (!email || !code) {
            console.error('Missing email or code:', { email: !!email, code: !!code })
            return createResponse(false, 'Email and code are required', code || '', email || '')
        }

        // Try to send email via Resend if API key is configured
        if (RESEND_API_KEY) {
            try {
                console.log(`Attempting to send OTP email to: ${email}`)

                const resendResponse = await fetch('https://api.resend.com/emails', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${RESEND_API_KEY}`,
                    },
                    body: JSON.stringify({
                        from: 'onboarding@resend.dev',
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

                console.log(`Resend API response status: ${resendResponse.status}`)

                if (resendResponse.ok) {
                    // Email sent successfully
                    let responseData = {}
                    try {
                        const responseText = await resendResponse.text()
                        responseData = responseText ? JSON.parse(responseText) : {}
                    } catch {
                        // Ignore parse errors
                    }

                    console.log(`Email sent successfully to: ${email}`)
                    return createResponse(true, 'Email sent via Resend', code, email)
                } else {
                    // Resend returned an error
                    const errorText = await resendResponse.text()
                    console.error('Resend API error:', resendResponse.status, errorText)
                    console.error('Email that failed:', email)

                    // Return code as fallback even if email failed
                    return createResponse(
                        false,
                        'Email sending failed - Code displayed below',
                        code,
                        email,
                        `Resend error (${resendResponse.status}): ${errorText}`
                    )
                }
            } catch (resendError: any) {
                console.error('Error calling Resend API:', resendError)
                // Fall through to return code as fallback
            }
        }

        // Fallback: Return code even if Resend is not configured or failed
        console.log(`OTP Code for ${email}: ${code} (email service not configured or failed)`)
        return createResponse(
            false,
            'Email service not configured or failed - Code displayed below',
            code,
            email,
            'Email service not available'
        )

    } catch (error: any) {
        console.error('Unexpected error in Edge Function:', error)
        console.error('Error stack:', error?.stack)
        console.error('Email attempted:', email)
        console.error('Code attempted:', code)

        // Always return 200 with code as fallback, even on unexpected errors
        return createResponse(
            false,
            'An error occurred - Code displayed below',
            code || '',
            email || '',
            error?.message || 'Unknown error occurred'
        )
    }
})
