import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASSWORD,
  },
});

export interface EmailOptions {
  to: string;
  subject: string;
  html: string;
}

class EmailService {
  static async sendEmail(options: EmailOptions): Promise<void> {
    await transporter.sendMail({
      from: process.env.EMAIL_FROM || process.env.SMTP_USER,
      to: options.to,
      subject: options.subject,
      html: options.html,
    });
  }

  static async sendVerificationEmail(
    email: string,
    code: string
  ): Promise<void> {
    const baseUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
    const verificationUrl = `${baseUrl}/verify-email?email=${encodeURIComponent(
      email
    )}&code=${encodeURIComponent(code)}`;
    const html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <h2>Verify your email</h2>
        <p>Use the code below to verify your email address:</p>
        <p style="font-size: 22px; letter-spacing: 4px; font-weight: bold; color: #111;">
          ${code}
        </p>
        <p>You can also verify using this link:</p>
        <p><a href="${verificationUrl}">${verificationUrl}</a></p>
        <p>This link expires in 24 hours.</p>
      </div>
    `;

    await this.sendEmail({
      to: email,
      subject: 'Rendivo - Verify your email',
      html,
    });
  }

  static async sendWelcomeEmail(email: string, name?: string): Promise<void> {
    const displayName = name || 'User';
    const html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <h2>Welcome, ${displayName}!</h2>
        <p>Your email has been verified and your account is ready.</p>
        <p><a href="${process.env.FRONTEND_URL}/login">Log in</a></p>
      </div>
    `;

    await this.sendEmail({
      to: email,
      subject: 'Rendivo - Welcome',
      html,
    });
  }

  static async sendPasswordResetCode(
    email: string,
    code: string
  ): Promise<void> {
    const html = `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <h2>Password reset code</h2>
        <p>Use the code below to reset your password:</p>
        <p style="font-size: 22px; letter-spacing: 4px; font-weight: bold; color: #111;">
          ${code}
        </p>
        <p>This code expires in 15 minutes.</p>
        <p>If you did not request this, you can ignore this email.</p>
      </div>
    `;

    await this.sendEmail({
      to: email,
      subject: 'Rendivo - Password reset code',
      html,
    });
  }
}

export default EmailService;
