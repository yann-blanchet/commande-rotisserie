import { supabase } from '../lib/supabase'

export interface AdminOTPRequest {
  email: string
}

export interface AdminOTPVerification {
  email: string
  code: string
}

export class AdminOTPService {
  /**
   * Request an OTP code for an admin by email
   */
  async requestOTP(email: string): Promise<{ success: boolean; message: string }> {
    try {
      // First, verify that the email exists in admin_users table
      const { data: admin, error: adminError } = await supabase
        .from('admin_users')
        .select('id, email')
        .eq('email', email.toLowerCase().trim())
        .single()

      if (adminError || !admin) {
        return {
          success: false,
          message: 'Email non trouvé. Vérifiez que cet email est autorisé comme administrateur.'
        }
      }

      // Generate 6-digit code
      const code = Math.floor(100000 + Math.random() * 900000).toString()

      // Store OTP in Supabase (expires in 10 minutes)
      const expiresAt = new Date()
      expiresAt.setMinutes(expiresAt.getMinutes() + 10)

      const { error } = await supabase
        .from('admin_otps')
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
      console.error('Error requesting admin OTP:', error)
      return {
        success: false,
        message: error.message || 'Erreur lors de la génération du code'
      }
    }
  }

  /**
   * Verify OTP code for admin
   */
  async verifyOTP(email: string, code: string): Promise<{ success: boolean; message: string }> {
    try {
      const { data, error } = await supabase
        .from('admin_otps')
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

      // Verify that email is in admin_users
      const { data: admin, error: adminError } = await supabase
        .from('admin_users')
        .select('id, email')
        .eq('email', email.toLowerCase().trim())
        .single()

      if (adminError || !admin) {
        return {
          success: false,
          message: 'Email admin non trouvé'
        }
      }

      // Mark as used
      await supabase
        .from('admin_otps')
        .update({ used: true })
        .eq('email', email.toLowerCase().trim())
        .eq('code', code)

      return {
        success: true,
        message: 'Code valide'
      }
    } catch (error: any) {
      console.error('Error verifying admin OTP:', error)
      return {
        success: false,
        message: error.message || 'Erreur lors de la vérification'
      }
    }
  }
}

export const adminOtpService = new AdminOTPService()







