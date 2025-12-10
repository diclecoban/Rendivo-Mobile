import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

// Shift attributes interface
export interface ShiftAttributes {
  id: number;
  staffId: number;
  businessId: number;
  shiftDate: Date;
  startTime: string;
  endTime: string;
  createdAt?: Date;
  updatedAt?: Date;
}

interface ShiftCreationAttributes extends Optional<ShiftAttributes, 'id'> {}

// Shift Model
class Shift extends Model<ShiftAttributes, ShiftCreationAttributes> implements ShiftAttributes {
  public id!: number;
  public staffId!: number;
  public businessId!: number;
  public shiftDate!: Date;
  public startTime!: string;
  public endTime!: string;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

Shift.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    staffId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'staff_members',
        key: 'id',
      },
    },
    businessId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'businesses',
        key: 'id',
      },
    },
    shiftDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    startTime: {
      type: DataTypes.TIME,
      allowNull: false,
    },
    endTime: {
      type: DataTypes.TIME,
      allowNull: false,
    },
  },
  {
    sequelize,
    tableName: 'shifts',
    timestamps: true,
  }
);

export default Shift;
