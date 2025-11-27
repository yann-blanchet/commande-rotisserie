import { supabase } from '../lib/supabase'

export interface OTPRequest {
  email: string
}

export interface OTPVerification {
  email: string
  code: string
}

export class OTPService {
  /**
   * Request an OTP code for a vendor by email
   */
  async requestOTP(email: string): Promise<{ success: boolean; message: string }> {
    try {
      // First, verify that the email exists in vendors table
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('id, email')
        .eq('email', email.toLowerCase().trim())
        .single()

      if (vendorError || !vendor) {
        return {
          success: false,
          message: 'Email non trouvé. Vérifiez que cet email est associé à un stand.'
        }
      }

      // Generate 6-digit code
      const code = Math.floor(100000 + Math.random() * 900000).toString()

      // Store OTP in Supabase (expires in 10 minutes)
      const expiresAt = new Date()
      expiresAt.setMinutes(expiresAt.getMinutes() + 10)

      const { error } = await supabase
        .from('trader_otps')
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
          // Fallback: show code in UI if email fails
          return {
            success: true,
            message: `Code OTP: ${code} (valide 10 minutes) - Email non envoyé, vérifiez votre configuration`
          }
        }

        // Check if function returned success
        if (functionData && functionData.success) {
          return {
            success: true,
            message: 'Code OTP envoyé par email. Vérifiez votre boîte de réception.'
          }
        } else {
          // Function executed but didn't return success
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
   * Verify OTP code and return vendor_id
   */
  async verifyOTP(email: string, code: string): Promise<{ success: boolean; message: string; vendorId?: string }> {
    try {
      const { data, error } = await supabase
        .from('trader_otps')
        .select('*')
        .eq('email', email.toLowerCase().trim())
        .eq('code', code)
        .eq('used', false)
        .single()

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

      // Get vendor_id from email
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('id')
        .eq('email', email.toLowerCase().trim())
        .single()

      if (vendorError || !vendor) {
        return {
          success: false,
          message: 'Email non trouvé'
        }
      }

      // Mark as used
      await supabase
        .from('trader_otps')
        .update({ used: true })
        .eq('email', email.toLowerCase().trim())
        .eq('code', code)

      // Note: If a Supabase Auth user exists for this email, they were created during registration
      // The vendor_id is stored in user_metadata, but we use OTP for authentication
      // The session is managed via localStorage with vendor_id

      return {
        success: true,
        message: 'Code valide',
        vendorId: vendor.id
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

export const otpService = new OTPService()

