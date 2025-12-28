import { Op } from 'sequelize';
import { Appointment, AppointmentReminder, Business, StaffMember, User } from '../models';
import notificationService from './notificationService';

const formatDate = (date: Date) => date.toISOString().split('T')[0];

const getDateWithOffset = (days: number) => {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + days);
  return date;
};

const buildReminderBody = (
  businessName: string,
  appointmentDate: string,
  startTime: string,
  whenLabel: string
) => {
  return `${businessName} randevunuz ${whenLabel}. (${appointmentDate} ${startTime.substring(0, 5)})`;
};

export const runAppointmentReminders = async (): Promise<void> => {
  const reminderConfigs = [
    { type: 'week' as const, days: 7, label: '1 hafta sonra' },
    { type: 'day' as const, days: 1, label: 'yarın' },
  ];

  for (const config of reminderConfigs) {
    const targetDate = formatDate(getDateWithOffset(config.days));
    const appointments = await Appointment.findAll({
      where: {
        appointmentDate: targetDate,
        status: { [Op.in]: ['confirmed', 'pending'] },
      },
      include: [
        {
          model: Business,
          as: 'business',
          attributes: ['businessName'],
        },
        {
          model: User,
          as: 'customer',
          attributes: ['id'],
        },
        {
          model: StaffMember,
          as: 'staff',
          include: [{ model: User, as: 'user', attributes: ['fullName'] }],
        },
      ],
    });

    for (const appointment of appointments) {
      const [reminder, created] = await AppointmentReminder.findOrCreate({
        where: {
          appointmentId: appointment.id,
          type: config.type,
        },
        defaults: {
          appointmentId: appointment.id,
          type: config.type,
        },
      });

      if (!created && reminder) continue;

      const businessName = appointment.business?.businessName || 'Rendivo Partner';
      const body = buildReminderBody(
        businessName,
        targetDate,
        appointment.startTime,
        config.label
      );

      await notificationService.sendToUsers(
        [appointment.customerId],
        {
          title: 'Randevu hatırlatması',
          body,
          data: {
            type:
              config.type === 'week'
                ? 'customer_reminder_week'
                : 'customer_reminder_day',
            appointmentId: String(appointment.id),
            reminderType: config.type,
          },
        }
      );
    }
  }
};
