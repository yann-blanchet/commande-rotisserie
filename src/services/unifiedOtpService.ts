import { supabase } from '../lib/supabase'

export type ProfileRole = 'vendor' | 'admin'

export interface OTPRequest {
  email: string
  role: ProfileRole
}

export interface OTPVerification {
  email: string
  code: string
  role: ProfileRole
}

export class UnifiedOTPService {
  /**
   * Request an OTP code for a profile (vendor or admin) by email
   */
  async requestOTP(email: string, role: ProfileRole): Promise<{ success: boolean; message: string }> {
    try {
      // First, verify that the email exists in profiles table with the correct role
      const normalizedEmail = email.toLowerCase().trim()
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id, email, role')
        .eq('email', normalizedEmail)
        .eq('role', role)
        .maybeSingle() // Use maybeSingle() instead of single() to avoid 406 errors

      if (profileError) {
        console.error('Error checking profile:', profileError)
        return {
          success: false,
          message: `Erreur lors de la vérification: ${profileError.message || 'Erreur inconnue'}`
        }
      }

      if (!profile) {
        const roleLabel = role === 'vendor' ? 'stand' : 'administrateur'
        return {
          success: false,
          message: `Email non trouvé. Vérifiez que cet email est associé à un ${roleLabel}.`
        }
      }

      // Generate 6-digit code
      const code = Math.floor(100000 + Math.random() * 900000).toString()

      // Store OTP in Supabase (expires in 10 minutes)
      const expiresAt = new Date()
      expiresAt.setMinutes(expiresAt.getMinutes() + 10)

      const { error } = await supabase
        .from('otps')
        .upsert({
          email: email.toLowerCase().trim(),
          code: code,
          expires_at: expiresAt.toISOString(),
          used: false
        }, {
          onConflict: 'email'
        })

      if (error) throw error

      // Send email via Supabase Edge Function
      try {
        const { data: functionData, error: functionError } = await supabase.functions.invoke('send-otp-email', {
          body: {
            email: email.toLowerCase().trim(),
            code: code
          }
        })

        if (functionError) {
          console.warn('Error sending email via function:', functionError)
          // Even if there's an error, try to extract code from error response if available
          // Supabase sometimes includes the response body in the error
          let fallbackCode = code
          try {
            // Check if error has response data with code
            if (functionError.context && functionError.context.body) {
              const errorBody = typeof functionError.context.body === 'string'
                ? JSON.parse(functionError.context.body)
                : functionError.context.body
              if (errorBody && errorBody.code) {
                fallbackCode = errorBody.code
              }
            }
          } catch (e) {
            // Ignore parsing errors, use original code
          }
          // Fallback: show code in UI if email fails
          return {
            success: true,
            message: `Code OTP: ${fallbackCode} (valide 10 minutes) - Email non envoyé, vérifiez votre configuration`
          }
        }

        // Check if function returned success
        if (functionData && functionData.success) {
          return {
            success: true,
            message: 'Code OTP envoyé par email. Vérifiez votre boîte de réception.'
          }
        } else if (functionData && functionData.code) {
          // Function returned error but included code as fallback
          console.warn('Email sending failed, but code available:', functionData)
          const errorMsg = functionData.error ? ` - ${functionData.error}` : ''
          return {
            success: true,
            message: `Code OTP: ${functionData.code} (valide 10 minutes) - Email non envoyé${errorMsg}`
          }
        } else {
          // Function executed but didn't return success or code
          // Use the code we generated locally as fallback
          console.warn('Function executed but returned:', functionData)
          return {
            success: true,
            message: `Code OTP: ${code} (valide 10 minutes) - Email non envoyé, vérifiez votre configuration`
          }
        }
      } catch (emailError: any) {
        console.warn('Error sending email:', emailError)
        // Fallback: show code in UI if email fails
        return {
          success: true,
          message: `Code OTP: ${code} (valide 10 minutes) - Email non envoyé, vérifiez votre configuration`
        }
      }
    } catch (error: any) {
      console.error('Error requesting OTP:', error)
      return {
        success: false,
        message: error.message || 'Erreur lors de la génération du code'
      }
    }
  }

  /**
   * Verify OTP code and return profile info
   */
  async verifyOTP(email: string, code: string, role: ProfileRole): Promise<{
    success: boolean
    message: string
    vendorId?: string
    profileId?: string
  }> {
    try {
      const normalizedEmail = email.toLowerCase().trim()
      const { data, error } = await supabase
        .from('otps')
        .select('*')
        .eq('email', normalizedEmail)
        .eq('code', code)
        .eq('used', false)
        .maybeSingle() // Use maybeSingle() instead of single() to avoid 406 errors

      if (error || !data) {
        return {
          success: false,
          message: 'Code invalide'
        }
      }

      // Check if expired
      const expiresAt = new Date(data.expires_at)
      if (expiresAt < new Date()) {
        return {
          success: false,
          message: 'Code expiré'
        }
      }

      // Get profile from email and role (use normalizedEmail from above)
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id, email, role')
        .eq('email', normalizedEmail)
        .eq('role', role)
        .maybeSingle() // Use maybeSingle() instead of single() to avoid 406 errors

      if (profileError) {
        console.error('Error checking profile during verification:', profileError)
        return {
          success: false,
          message: `Erreur lors de la vérification: ${profileError.message || 'Erreur inconnue'}`
        }
      }

      if (!profile) {
        return {
          success: false,
          message: 'Email non trouvé'
        }
      }

      // Mark as used
      await supabase
        .from('otps')
        .update({ used: true })
        .eq('email', normalizedEmail)
        .eq('code', code)

      // If vendor, get vendor_id (take the first vendor if multiple stands exist)
      let vendorId: string | undefined
      if (role === 'vendor') {
        const { data: vendors, error: vendorError } = await supabase
          .from('vendors')
          .select('id')
          .eq('profile_id', profile.id)
          .limit(1)

        if (!vendorError && vendors && vendors.length > 0 && vendors[0]) {
          vendorId = vendors[0].id
        }
      }

      return {
        success: true,
        message: 'Code valide',
        vendorId,
        profileId: profile.id
      }
    } catch (error: any) {
      console.error('Error verifying OTP:', error)
      return {
        success: false,
        message: error.message || 'Erreur lors de la vérification'
      }
    }
  }
}

export const unifiedOtpService = new UnifiedOTPService()

