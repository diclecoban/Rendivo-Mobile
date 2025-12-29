import {
  Appointment,
  AppointmentService,
  Business,
  StaffMember,
  Service,
  User,
} from '../models';
import EmailService from './emailService';
import { notificationService } from './notificationService';

export type AppointmentWithRelations = Appointment & {
  business?: Business & { owner?: User };
  staff?: StaffMember & { user?: User };
  customer?: User;
  services?: Service[];
};

interface CancellationOptions {
  cancelledBy: 'customer' | 'business';
  notifyStaff?: boolean;
}

export async function cancelAppointmentRecord(
  appointment: AppointmentWithRelations,
  options: CancellationOptions
): Promise<void> {
  const { cancelledBy, notifyStaff = true } = options;
  const appointmentId = appointment.id?.toString();
  const appointmentDate = appointment.appointmentDate;
  const startTime = appointment.startTime;
  const businessName = appointment.business?.businessName || 'Rendivo Partner';
  const customer = appointment.customer;
  const owner = appointment.business?.owner;
  const staffUser = appointment.staff?.user;
  const serviceNames =
    appointment.services?.map((service) => service.name).filter(Boolean) ?? [];

  const customerId = appointment.customerId;
  const ownerId = owner?.id;
  const staffUserId = staffUser?.id;
  const customerEmail = customer?.email;
  const customerName = customer?.fullName || 'Customer';
  const ownerEmail = owner?.email || appointment.business?.email;
  const ownerName = owner?.fullName || owner?.firstName;
  const staffEmail = staffUser?.email;
  const staffName =
    staffUser?.fullName ||
    [staffUser?.firstName, staffUser?.lastName].filter(Boolean).join(' ') ||
    undefined;

  const dateLabel = appointmentDate ? new Date(appointmentDate).toDateString() : '';
  const startLabel = startTime ? startTime.substring(0, 5) : '';
  const cancelType =
    cancelledBy === 'customer'
      ? 'appointment_cancelled_by_customer'
      : 'appointment_cancelled_by_business';

  try {
    await AppointmentService.destroy({ where: { appointmentId: appointment.id } });
  } catch (error) {
    console.error('Failed to remove appointment service records:', error);
  }

  await appointment.destroy();

  if (customerEmail) {
    try {
      await EmailService.sendAppointmentCancellation({
        email: customerEmail,
        name: customerName,
        businessName,
        appointmentDate: dateLabel,
        startTime: startLabel,
      });
    } catch (emailError) {
      console.error('Failed to send cancellation email:', emailError);
    }
  }

  if (ownerEmail) {
    try {
      await EmailService.sendBusinessAppointmentCancelled({
        email: ownerEmail as string,
        ownerName,
        businessName,
        customerName,
        appointmentDate: dateLabel,
        startTime: startLabel,
        services: serviceNames,
        staffName,
      });
    } catch (businessEmailError) {
      console.error('Failed to send business cancellation email:', businessEmailError);
    }
  }

  if (notifyStaff && staffEmail) {
    try {
      await EmailService.sendStaffAppointmentCancelled({
        email: staffEmail as string,
        staffName,
        businessName,
        customerName,
        appointmentDate: dateLabel,
        startTime: startLabel,
        services: serviceNames,
      });
    } catch (staffEmailError) {
      console.error('Failed to send staff cancellation email:', staffEmailError);
    }
  }

  const notificationTasks: Promise<void>[] = [];

  if (customerEmail && customerId) {
    notificationTasks.push(
      notificationService
        .sendNotification({
          userId: customerId.toString(),
          type: cancelType,
          title: 'Appointment cancelled',
          message:
            cancelledBy === 'customer'
              ? 'Your appointment was cancelled successfully.'
              : 'Your appointment was cancelled by the business.',
          relatedId: appointmentId,
          relatedType: 'appointment',
          actionUrl: `/appointments/${appointmentId}`,
        })
        .catch((error) => {
          console.error('Failed to send customer cancellation notification:', error);
        })
    );
  }

  if (ownerId) {
    notificationTasks.push(
      notificationService
        .sendNotification({
          userId: ownerId.toString(),
          type: cancelType,
          title: 'Appointment cancelled',
          message:
            cancelledBy === 'customer'
              ? `${customerName} cancelled the appointment.`
              : 'The appointment was cancelled by the business.',
          relatedId: appointmentId,
          relatedType: 'appointment',
          actionUrl: `/appointments/${appointmentId}`,
        })
        .catch((error) => {
          console.error('Failed to send owner cancellation notification:', error);
        })
    );
  }

  if (notifyStaff && staffUserId) {
    notificationTasks.push(
      notificationService
        .sendNotification({
          userId: staffUserId.toString(),
          type: cancelType,
          title: 'Appointment cancelled',
          message:
            cancelledBy === 'customer'
              ? `${customerName} cancelled the appointment.`
              : 'The appointment was cancelled by the business.',
          relatedId: appointmentId,
          relatedType: 'appointment',
          actionUrl: `/appointments/${appointmentId}`,
        })
        .catch((error) => {
          console.error('Failed to send staff cancellation notification:', error);
        })
    );
  }

  if (notificationTasks.length > 0) {
    await Promise.all(notificationTasks);
  }
}
