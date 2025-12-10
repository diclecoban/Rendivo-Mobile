import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

// AppointmentService attributes interface (junction table)
export interface AppointmentServiceAttributes {
  id: number;
  appointmentId: number;
  serviceId: number;
  createdAt?: Date;
  updatedAt?: Date;
}

interface AppointmentServiceCreationAttributes extends Optional<AppointmentServiceAttributes, 'id'> {}

// AppointmentService Model (Many-to-Many relationship)
class AppointmentService extends Model<AppointmentServiceAttributes, AppointmentServiceCreationAttributes> 
  implements AppointmentServiceAttributes {
  public id!: number;
  public appointmentId!: number;
  public serviceId!: number;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

AppointmentService.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    appointmentId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'appointments',
        key: 'id',
      },
    },
    serviceId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'services',
        key: 'id',
      },
    },
  },
  {
    sequelize,
    tableName: 'appointment_services',
    timestamps: true,
  }
);

export default AppointmentService;
