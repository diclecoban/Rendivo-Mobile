import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

// Business approval status
export enum ApprovalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected'
}

// Business attributes interface
export interface BusinessAttributes {
  id: number;
  ownerId: number;
  businessName: string;
  businessType?: string;
  description?: string;
  address?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  country?: string;
  phone?: string;
  email?: string;
  website?: string;
  logo?: string;
  businessId: string; // Unique business identifier for staff to join
  approvalStatus: ApprovalStatus;
  approvedAt?: Date;
  rejectionReason?: string | null;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

interface BusinessCreationAttributes extends Optional<BusinessAttributes, 'id' | 'businessId' | 'isActive' | 'approvalStatus'> {}

// Business Model
class Business extends Model<BusinessAttributes, BusinessCreationAttributes> implements BusinessAttributes {
  public id!: number;
  public ownerId!: number;
  public businessName!: string;
  public businessType?: string;
  public description?: string;
  public address?: string;
  public city?: string;
  public state?: string;
  public zipCode?: string;
  public country?: string;
  public phone?: string;
  public email?: string;
  public website?: string;
  public logo?: string;
  public businessId!: string;
  public approvalStatus!: ApprovalStatus;
  public approvedAt?: Date;
  public rejectionReason?: string | null;
  public isActive!: boolean;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

Business.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    ownerId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
    },
    businessName: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    businessType: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    address: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    city: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    state: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    zipCode: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    country: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    phone: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    website: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    logo: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    businessId: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
      defaultValue: () => `BIZ${Date.now()}${Math.random().toString(36).substr(2, 9).toUpperCase()}`,
    },
    approvalStatus: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected'),
      allowNull: false,
      defaultValue: 'pending',
    },
    approvedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    rejectionReason: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    sequelize,
    tableName: 'businesses',
    timestamps: true,
    hooks: {
      beforeValidate: (business: Business) => {
        // Generate unique business ID if not provided
        if (!business.businessId) {
          business.businessId = `BIZ${Date.now()}${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
        }
      },
      beforeCreate: (business: Business) => {
        // Double-check business ID exists before creation
        if (!business.businessId) {
          business.businessId = `BIZ${Date.now()}${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
        }
      },
    },
  }
);

export default Business;
