import cron from 'node-cron';
import { Op } from 'sequelize';
import { Appointment, Business, User, Service, StaffMember } from '../models';
import { AppointmentStatus } from '../models/Appointment';
import { notificationService } from './notificationService';

// Track sent reminders to avoid duplicates
const sentReminders = new Map<string, Set<string>>();

// Initialize reminder tracking
['week', 'day', 'hour'].forEach(type => {
  sentReminders.set(type, new Set());
});

// Check if reminder already sent
function isReminderSent(appointmentId: number, type: 'week' | 'day' | 'hour'): boolean {
  const key = `${appointmentId}`;
  return sentReminders.get(type)?.has(key) || false;
}

// Mark reminder as sent
function markReminderSent(appointmentId: number, type: 'week' | 'day' | 'hour'): void {
  const key = `${appointmentId}`;
  sentReminders.get(type)?.add(key);
}

// Send 1 week reminder
async function sendWeekReminders() {
  try {
    const weekFromNow = new Date();
    weekFromNow.setDate(weekFromNow.getDate() + 7);
    
    const startOfDay = new Date(weekFromNow);
    startOfDay.setHours(0, 0, 0, 0);
    
    const endOfDay = new Date(weekFromNow);
    endOfDay.setHours(23, 59, 59, 999);

    const appointments = await Appointment.findAll({
      where: {
        appointmentDate: {
          [Op.between]: [startOfDay, endOfDay]
        },
        status: AppointmentStatus.CONFIRMED
      },
      include: [
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'email', 'firstName', 'lastName']
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address']
        },
        {
          model: Service,
          as: 'services',
          through: { attributes: [] }
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName']
          }]
        }
      ]
    });

    console.log(`📅 Found ${appointments.length} appointments for 1 week reminder`);

    for (const appointment of appointments) {
      if (isReminderSent(appointment.id, 'week')) {
        continue;
      }

      const appointmentData = appointment.toJSON() as any;
      const serviceNames = appointmentData.services?.map((s: any) => s.name).join(', ') || 'services';
      const appointmentDateTime = `${appointment.appointmentDate} at ${appointment.startTime}`;

      await notificationService.sendNotification({
        userId: appointment.customerId.toString(),
        type: 'appointment_reminder_week',
        title: '📅 Reminder: Appointment in 1 Week!',
        message: `Just a heads up! Your appointment at ${appointmentData.business.businessName} is coming up in one week 💙`,
        relatedId: appointment.id.toString(),
        relatedType: 'appointment',
        actionUrl: `/appointment/${appointment.id}`,
        emailData: {
          to: appointmentData.customer.email,
          subject: '📅 Reminder: Your Appointment is Next Week!',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">📅 Friendly Reminder!</h2>
              <p style="color: #555; line-height: 1.6;">Hi ${appointmentData.customer.firstName}! 👋</p>
              <p style="color: #555; line-height: 1.6;">Just a quick reminder that your appointment is coming up in <strong>one week</strong>! We're looking forward to seeing you! 🌟</p>
              <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${appointmentData.business.businessName}</p>
                <p style="margin: 5px 0;"><strong>✨ Service:</strong> ${serviceNames}</p>
                <p style="margin: 5px 0;"><strong>📅 Date & Time:</strong> ${appointmentDateTime}</p>
                <p style="margin: 5px 0;"><strong>👤 Staff:</strong> ${appointmentData.staff?.user?.fullName || 'N/A'}</p>
              </div>
              <p style="color: #555; line-height: 1.6;">We can't wait to see you! If you need to make any changes, just let us know. 💙</p>
              <p style="color: #999; font-size: 12px; margin-top: 30px;">See you soon! ✨</p>
            </div>
          `
        }
      });

      markReminderSent(appointment.id, 'week');
      console.log(`✅ Sent 1 week reminder for appointment ${appointment.id}`);
    }
  } catch (error) {
    console.error('Error sending week reminders:', error);
  }
}

// Send 1 day reminder
async function sendDayReminders() {
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const startOfDay = new Date(tomorrow);
    startOfDay.setHours(0, 0, 0, 0);
    
    const endOfDay = new Date(tomorrow);
    endOfDay.setHours(23, 59, 59, 999);

    const appointments = await Appointment.findAll({
      where: {
        appointmentDate: {
          [Op.between]: [startOfDay, endOfDay]
        },
        status: AppointmentStatus.CONFIRMED
      },
      include: [
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'email', 'firstName', 'lastName']
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address']
        },
        {
          model: Service,
          as: 'services',
          through: { attributes: [] }
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName']
          }]
        }
      ]
    });

    console.log(`📅 Found ${appointments.length} appointments for 1 day reminder`);

    for (const appointment of appointments) {
      if (isReminderSent(appointment.id, 'day')) {
        continue;
      }

      const appointmentData = appointment.toJSON() as any;
      const serviceNames = appointmentData.services?.map((s: any) => s.name).join(', ') || 'services';
      const appointmentDateTime = `${appointment.appointmentDate} at ${appointment.startTime}`;

      await notificationService.sendNotification({
        userId: appointment.customerId.toString(),
        type: 'appointment_reminder_day',
        title: '⏰ Tomorrow is the Day!',
        message: `Your appointment at ${appointmentData.business.businessName} is tomorrow! Can't wait to see you! 💙`,
        relatedId: appointment.id.toString(),
        relatedType: 'appointment',
        actionUrl: `/appointment/${appointment.id}`,
        emailData: {
          to: appointmentData.customer.email,
          subject: '⏰ Reminder: Your Appointment is Tomorrow!',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">⏰ Almost Time!</h2>
              <p style="color: #555; line-height: 1.6;">Hi ${appointmentData.customer.firstName}! 👋</p>
              <p style="color: #555; line-height: 1.6;">Exciting news! Your appointment is <strong>tomorrow</strong>! We're so excited to see you! 🎉</p>
              <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${appointmentData.business.businessName}</p>
                <p style="margin: 5px 0;"><strong>✨ Service:</strong> ${serviceNames}</p>
                <p style="margin: 5px 0;"><strong>📅 Date & Time:</strong> ${appointmentDateTime}</p>
                <p style="margin: 5px 0;"><strong>👤 Staff:</strong> ${appointmentData.staff?.user?.fullName || 'N/A'}</p>
                <p style="margin: 5px 0;"><strong>📍 Address:</strong> ${appointmentData.business.address}</p>
              </div>
              <p style="color: #555; line-height: 1.6;">Pro tip: Arrive a few minutes early so we can start right on time! ⏰</p>
              <p style="color: #555; line-height: 1.6;">Need to reschedule? Just let us know! 💙</p>
              <p style="color: #999; font-size: 12px; margin-top: 30px;">See you tomorrow! 🌟</p>
            </div>
          `
        }
      });

      markReminderSent(appointment.id, 'day');
      console.log(`✅ Sent 1 day reminder for appointment ${appointment.id}`);
    }
  } catch (error) {
    console.error('Error sending day reminders:', error);
  }
}

// Send 1 hour reminder
async function sendHourReminders() {
  try {
    const now = new Date();

    const appointments = await Appointment.findAll({
      where: {
        appointmentDate: now.toISOString().split('T')[0],
        status: AppointmentStatus.CONFIRMED
      },
      include: [
        {
          model: User,
          as: 'customer',
          attributes: ['id', 'email', 'firstName', 'lastName']
        },
        {
          model: Business,
          as: 'business',
          attributes: ['id', 'businessName', 'address']
        },
        {
          model: Service,
          as: 'services',
          through: { attributes: [] }
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{
            model: User,
            as: 'user',
            attributes: ['fullName']
          }]
        }
      ]
    });

    // Filter appointments that are approximately 1 hour away
    const upcomingAppointments = appointments.filter(apt => {
      if (isReminderSent(apt.id, 'hour')) return false;
      
      const [hours, minutes] = apt.startTime.split(':').map(Number);
      const appointmentTime = new Date(now);
      appointmentTime.setHours(hours, minutes, 0, 0);
      
      const timeDiff = appointmentTime.getTime() - now.getTime();
      const hoursDiff = timeDiff / (1000 * 60 * 60);
      
      // Send reminder if appointment is between 50-70 minutes away
      return hoursDiff >= 0.83 && hoursDiff <= 1.17;
    });

    console.log(`📅 Found ${upcomingAppointments.length} appointments for 1 hour reminder`);

    for (const appointment of upcomingAppointments) {
      const appointmentData = appointment.toJSON() as any;
      const serviceNames = appointmentData.services?.map((s: any) => s.name).join(', ') || 'services';

      await notificationService.sendNotification({
        userId: appointment.customerId.toString(),
        type: 'appointment_reminder_day',
        title: '🔔 Your Appointment is in 1 Hour!',
        message: `Time to get ready! Your appointment at ${appointmentData.business.businessName} starts soon! 💙`,
        relatedId: appointment.id.toString(),
        relatedType: 'appointment',
        actionUrl: `/appointment/${appointment.id}`,
        emailData: {
          to: appointmentData.customer.email,
          subject: '🔔 Reminder: Your Appointment Starts in 1 Hour!',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <h2 style="color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px;">🔔 It's Almost Time!</h2>
              <p style="color: #555; line-height: 1.6;">Hi ${appointmentData.customer.firstName}! 👋</p>
              <p style="color: #555; line-height: 1.6;">This is it! Your appointment starts in about <strong>1 hour</strong>! Time to head out! 🚗✨</p>
              <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007bff;">
                <p style="margin: 5px 0;"><strong>🏢 Business:</strong> ${appointmentData.business.businessName}</p>
                <p style="margin: 5px 0;"><strong>✨ Service:</strong> ${serviceNames}</p>
                <p style="margin: 5px 0;"><strong>⏰ Time:</strong> ${appointment.startTime}</p>
                <p style="margin: 5px 0;"><strong>👤 Staff:</strong> ${appointmentData.staff?.user?.fullName || 'N/A'}</p>
                <p style="margin: 5px 0;"><strong>📍 Address:</strong> ${appointmentData.business.address}</p>
              </div>
              <p style="color: #555; line-height: 1.6;">Don't forget to leave a little early to avoid traffic! We're so excited to see you! 💙</p>
              <p style="color: #999; font-size: 12px; margin-top: 30px;">See you very soon! 🎉</p>
            </div>
          `
        }
      });

      markReminderSent(appointment.id, 'hour');
      console.log(`✅ Sent 1 hour reminder for appointment ${appointment.id}`);
    }
  } catch (error) {
    console.error('Error sending hour reminders:', error);
  }
}

// Initialize scheduler
export function initializeReminderScheduler() {
  console.log('🕐 Initializing reminder scheduler...');

  // Run 1 week reminders daily at 9 AM
  cron.schedule('0 9 * * *', async () => {
    console.log('🔔 Running 1 week reminder check...');
    await sendWeekReminders();
  });

  // Run 1 day reminders daily at 9 AM
  cron.schedule('0 9 * * *', async () => {
    console.log('🔔 Running 1 day reminder check...');
    await sendDayReminders();
  });

  // Run 1 hour reminders every 15 minutes
  cron.schedule('*/15 * * * *', async () => {
    console.log('🔔 Running 1 hour reminder check...');
    await sendHourReminders();
  });

  console.log('✅ Reminder scheduler initialized successfully');
  console.log('   - 1 week reminders: Daily at 9 AM');
  console.log('   - 1 day reminders: Daily at 9 AM');
  console.log('   - 1 hour reminders: Every 15 minutes');
}

// Clear reminder tracking (call this periodically to prevent memory issues)
export function clearOldReminderTracking() {
  console.log('🧹 Clearing old reminder tracking data...');
  sentReminders.forEach(set => set.clear());
}

// Run cleanup daily at midnight
cron.schedule('0 0 * * *', () => {
  clearOldReminderTracking();
});
