import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

// StaffMember attributes interface
export interface StaffMemberAttributes {
  id: number;
  userId: number;
  businessId: number;
  position?: string;
  isActive: boolean;
  joinedAt: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

interface StaffMemberCreationAttributes extends Optional<StaffMemberAttributes, 'id' | 'isActive' | 'joinedAt'> {}

// StaffMember Model
class StaffMember extends Model<StaffMemberAttributes, StaffMemberCreationAttributes> implements StaffMemberAttributes {
  public id!: number;
  public userId!: number;
  public businessId!: number;
  public position?: string;
  public isActive!: boolean;
  public joinedAt!: Date;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

StaffMember.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'users',
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
    position: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    joinedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    sequelize,
    tableName: 'staff_members',
    timestamps: true,
  }
);

export default StaffMember;
