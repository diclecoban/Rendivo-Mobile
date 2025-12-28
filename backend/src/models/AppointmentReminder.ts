import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

export type ReminderType = 'week' | 'day';

export interface AppointmentReminderAttributes {
  id: number;
  appointmentId: number;
  type: ReminderType;
  sentAt: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

interface AppointmentReminderCreationAttributes
  extends Optional<AppointmentReminderAttributes, 'id' | 'sentAt'> {}

class AppointmentReminder
  extends Model<AppointmentReminderAttributes, AppointmentReminderCreationAttributes>
  implements AppointmentReminderAttributes
{
  public id!: number;
  public appointmentId!: number;
  public type!: ReminderType;
  public sentAt!: Date;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

AppointmentReminder.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    appointmentId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
    },
    type: {
      type: DataTypes.ENUM('week', 'day'),
      allowNull: false,
    },
    sentAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    sequelize,
    tableName: 'appointment_reminders',
    timestamps: true,
    indexes: [
      {
        unique: true,
        fields: ['appointmentId', 'type'],
      },
    ],
  }
);

export default AppointmentReminder;
