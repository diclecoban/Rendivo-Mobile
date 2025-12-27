import User from './User';
import Business, { BusinessApprovalStatus } from './Business';
import StaffMember from './StaffMember';
import Service from './Service';
import Appointment from './Appointment';
import AppointmentService from './AppointmentService';
import Shift from './Shift';

// Define associations
User.hasOne(Business, {
  foreignKey: 'ownerId',
  as: 'ownedBusiness',
});

Business.belongsTo(User, {
  foreignKey: 'ownerId',
  as: 'owner',
});

User.hasMany(Business, {
  foreignKey: 'reviewedBy',
  as: 'reviewedBusinesses',
});

Business.belongsTo(User, {
  foreignKey: 'reviewedBy',
  as: 'reviewer',
});

User.hasMany(StaffMember, {
  foreignKey: 'userId',
  as: 'staffMemberships',
});

StaffMember.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user',
});

Business.hasMany(StaffMember, {
  foreignKey: 'businessId',
  as: 'staff',
});

StaffMember.belongsTo(Business, {
  foreignKey: 'businessId',
  as: 'business',
});

// Service associations
Business.hasMany(Service, {
  foreignKey: 'businessId',
  as: 'services',
});

Service.belongsTo(Business, {
  foreignKey: 'businessId',
  as: 'business',
});

// Appointment associations
User.hasMany(Appointment, {
  foreignKey: 'customerId',
  as: 'appointments',
});

Appointment.belongsTo(User, {
  foreignKey: 'customerId',
  as: 'customer',
});

Business.hasMany(Appointment, {
  foreignKey: 'businessId',
  as: 'appointments',
});

Appointment.belongsTo(Business, {
  foreignKey: 'businessId',
  as: 'business',
});

StaffMember.hasMany(Appointment, {
  foreignKey: 'staffId',
  as: 'appointments',
});

Appointment.belongsTo(StaffMember, {
  foreignKey: 'staffId',
  as: 'staff',
});

// Appointment-Service many-to-many relationship
Appointment.belongsToMany(Service, {
  through: AppointmentService,
  foreignKey: 'appointmentId',
  otherKey: 'serviceId',
  as: 'services',
});

Service.belongsToMany(Appointment, {
  through: AppointmentService,
  foreignKey: 'serviceId',
  otherKey: 'appointmentId',
  as: 'appointments',
});

// Shift associations
StaffMember.hasMany(Shift, {
  foreignKey: 'staffId',
  as: 'shifts',
});

Shift.belongsTo(StaffMember, {
  foreignKey: 'staffId',
  as: 'staff',
});

Business.hasMany(Shift, {
  foreignKey: 'businessId',
  as: 'shifts',
});

Shift.belongsTo(Business, {
  foreignKey: 'businessId',
  as: 'business',
});

export { User, Business, StaffMember, Service, Appointment, AppointmentService, Shift, BusinessApprovalStatus };
