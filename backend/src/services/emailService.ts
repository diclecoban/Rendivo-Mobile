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

const BRAND_NAME = process.env.EMAIL_BRAND_NAME || 'Rendivo';
const BRAND_COLOR = process.env.EMAIL_BRAND_COLOR || '#E91E63';
const BRAND_ACCENT = process.env.EMAIL_BRAND_ACCENT || '#FCE4EC';
const BRAND_LOGO = process.env.EMAIL_LOGO_URL;

const renderBrandHeader = (): string => {
  if (BRAND_LOGO) {
    return `<img src="${BRAND_LOGO}" alt="${BRAND_NAME} logo" style="max-width:140px;height:auto;margin-bottom:8px;"/>`;
  }
  return `<div style="font-size:20px;font-weight:700;color:${BRAND_COLOR};">${BRAND_NAME}</div>`;
};

const renderEmailLayout = (title: string, body: string): string => `
  <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; background:${BRAND_ACCENT}; padding:32px;">
    <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;box-shadow:0 8px 20px rgba(0,0,0,0.08);">
      <div style="text-align:center;padding:28px 24px 8px;">
        ${renderBrandHeader()}
        <p style="margin:0;color:#666;font-size:14px;">${BRAND_NAME} notifications</p>
      </div>
      <div style="padding:0 24px 24px;border-top:4px solid ${BRAND_COLOR};">
        <h2 style="color:${BRAND_COLOR};font-size:22px;margin-top:24px;">${title}</h2>
        ${body}
        <p style="font-size:12px;color:#999;border-top:1px solid #eee;margin-top:24px;padding-top:16px;">
          This message was sent automatically by ${BRAND_NAME}. Please do not reply directly to this email.
        </p>
      </div>
    </div>
  </div>
`;

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
      subject: 'Rendivo - Verify your Email',
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
      subject: 'Rendivo - Welcome!',
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
      subject: 'Rendivo - Reset Password',
      html,
    });
  }

  static async sendAppointmentConfirmation(options: {
    email: string;
    name?: string;
    businessName: string;
    appointmentDate: string;
    startTime: string;
    endTime: string;
  }): Promise<void> {
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.name ?? 'there'},</p>
        <p style="margin:0 0 12px;">We are pleased to confirm your booking with <strong>${options.businessName}</strong>.</p>
        <p style="margin:0 0 12px;"><strong>Date:</strong> ${options.appointmentDate}<br/>
           <strong>Time:</strong> ${options.startTime} - ${options.endTime}</p>
        <p style="margin:0;">You can review or update this appointment anytime inside the ${BRAND_NAME} application.</p>
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Your appointment is confirmed ✨</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - Appointment Confirmed`,
      html,
    });
  }

  static async sendAppointmentCancellation(options: {
    email: string;
    name?: string;
    businessName: string;
    appointmentDate: string;
    startTime: string;
  }): Promise<void> {
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.name ?? 'there'},</p>
        <p style="margin:0 0 12px;">This is to confirm that your booking with <strong>${options.businessName}</strong> scheduled on <strong>${options.appointmentDate}</strong> at <strong>${options.startTime}</strong> was cancelled.</p>
        <p style="margin:0;">Whenever you are ready, you can choose a new time directly inside the ${BRAND_NAME} application.</p>
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Your appointment was cancelled 😔</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - Appointment Cancelled`,
      html,
    });
  }

  static async sendAppointmentRescheduled(options: {
    email: string;
    name?: string;
    businessName: string;
    previousDate: string;
    previousStartTime: string;
    newDate: string;
    newStartTime: string;
    newEndTime: string;
  }): Promise<void> {
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.name ?? 'there'},</p>
        <p style="margin:0 0 12px;">Your appointment with <strong>${options.businessName}</strong> has been rescheduled.</p>
        <p style="margin:0 0 8px;"><strong>Previous:</strong> ${options.previousDate} at ${options.previousStartTime}</p>
        <p style="margin:0 0 12px;"><strong>New schedule:</strong> ${options.newDate} from ${options.newStartTime} to ${options.newEndTime}</p>
        <p style="margin:0;">If the new time is not suitable, you can adjust it inside the ${BRAND_NAME} application.</p>
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Your appointment was rescheduled ✍🏼</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - Appointment rescheduled`,
      html,
    });
  }

  static async sendBusinessAppointmentCreated(options: {
    email: string;
    ownerName?: string;
    businessName: string;
    customerName: string;
    appointmentDate: string;
    startTime: string;
    endTime: string;
    services?: string[];
    staffName?: string;
  }): Promise<void> {
    const servicesBlock =
      options.services && options.services.length > 0
        ? `<p style="margin:0 0 12px;"><strong>Services:</strong> ${options.services.join(', ')}</p>`
        : '';
    const staffBlock = options.staffName
      ? `<p style="margin:0 0 12px;"><strong>Assigned to:</strong> ${options.staffName}</p>`
      : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.ownerName ?? 'there'},</p>
        <p style="margin:0 0 12px;"><strong>${options.customerName}</strong> booked a new appointment at <strong>${options.businessName}</strong>.</p>
        <p style="margin:0 0 12px;"><strong>Date:</strong> ${options.appointmentDate}<br/>
           <strong>Time:</strong> ${options.startTime} - ${options.endTime}</p>
        ${servicesBlock}
        ${staffBlock}
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">New appointment booked</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - New booking on ${options.appointmentDate}`,
      html,
    });
  }

  static async sendBusinessAppointmentCancelled(options: {
    email: string;
    ownerName?: string;
    businessName: string;
    customerName: string;
    appointmentDate: string;
    startTime: string;
    services?: string[];
    staffName?: string;
  }): Promise<void> {
    const servicesBlock =
      options.services && options.services.length > 0
        ? `<p style="margin:0 0 12px;"><strong>Services:</strong> ${options.services.join(', ')}</p>`
        : '';
    const staffBlock = options.staffName
      ? `<p style="margin:0 0 12px;"><strong>Assigned to:</strong> ${options.staffName}</p>`
      : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.ownerName ?? 'there'},</p>
        <p style="margin:0 0 12px;">We wanted to let you know that <strong>${options.customerName}</strong> cancelled their appointment at <strong>${options.businessName}</strong>.</p>
        <p style="margin:0 0 12px;"><strong>Date:</strong> ${options.appointmentDate}<br/>
           <strong>Time:</strong> ${options.startTime}</p>
        ${servicesBlock}
        ${staffBlock}
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Appointment cancelled</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - Booking cancelled (${options.appointmentDate})`,
      html,
    });
  }

  static async sendStaffAppointmentAssigned(options: {
    email: string;
    staffName?: string;
    businessName: string;
    customerName: string;
    appointmentDate: string;
    startTime: string;
    endTime: string;
    services?: string[];
  }): Promise<void> {
    const servicesBlock =
      options.services && options.services.length > 0
        ? `<p style="margin:0 0 12px;"><strong>Services:</strong> ${options.services.join(', ')}</p>`
        : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hi ${options.staffName ?? 'there'},</p>
        <p style="margin:0 0 12px;">You have a new appointment at <strong>${options.businessName}</strong>.</p>
        <p style="margin:0 0 12px;"><strong>Client:</strong> ${options.customerName}</p>
        <p style="margin:0 0 12px;"><strong>Date:</strong> ${options.appointmentDate}<br/>
           <strong>Time:</strong> ${options.startTime} - ${options.endTime}</p>
        ${servicesBlock}
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">New appointment assigned</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - ${options.businessName} appointment (${options.appointmentDate})`,
      html,
    });
  }

  static async sendStaffAppointmentCancelled(options: {
    email: string;
    staffName?: string;
    businessName: string;
    customerName: string;
    appointmentDate: string;
    startTime: string;
    services?: string[];
  }): Promise<void> {
    const servicesBlock =
      options.services && options.services.length > 0
        ? `<p style="margin:0 0 12px;"><strong>Services:</strong> ${options.services.join(', ')}</p>`
        : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hi ${options.staffName ?? 'there'},</p>
        <p style="margin:0 0 12px;">The appointment with <strong>${options.customerName}</strong> at <strong>${options.businessName}</strong> was cancelled.</p>
        <p style="margin:0 0 12px;"><strong>Date:</strong> ${options.appointmentDate}<br/>
           <strong>Time:</strong> ${options.startTime}</p>
        ${servicesBlock}
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Appointment cancelled</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - Appointment cancelled (${options.appointmentDate})`,
      html,
    });
  }

  static async sendBusinessStaffAdded(options: {
    email: string;
    ownerName?: string;
    businessName: string;
    staffName: string;
    staffEmail?: string;
  }): Promise<void> {
    const contactBlock = options.staffEmail
      ? `<p style="margin:0 0 12px;"><strong>Staff email:</strong> ${options.staffEmail}</p>`
      : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.ownerName ?? 'there'},</p>
        <p style="margin:0 0 12px;"><strong>${options.staffName}</strong> just joined <strong>${options.businessName}</strong>.</p>
        ${contactBlock}
        <p style="margin:0;">Share shifts or appointments with them so they can start working immediately.</p>
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">New staff member added</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - ${options.staffName} joined your team`,
      html,
    });
  }

  static async sendBusinessStaffRemoved(options: {
    email: string;
    ownerName?: string;
    businessName: string;
    staffName: string;
    staffEmail?: string;
  }): Promise<void> {
    const contactBlock = options.staffEmail
      ? `<p style="margin:0 0 12px;"><strong>Staff email:</strong> ${options.staffEmail}</p>`
      : '';
    const body = `
      <div style="text-align:center;">
        <p style="margin:0 0 12px;">Hello ${options.ownerName ?? 'there'},</p>
        <p style="margin:0 0 12px;"><strong>${options.staffName}</strong> has been removed from <strong>${options.businessName}</strong>.</p>
        ${contactBlock}
        <p style="margin:0;">Their access to Rendivo has been revoked.</p>
      </div>
    `;
    const html = renderEmailLayout('<span style="display:block;text-align:center;">Staff member removed</span>', body);

    await this.sendEmail({
      to: options.email,
      subject: `Rendivo - ${options.staffName} removed from your team`,
      html,
    });
  }
}

export default EmailService;