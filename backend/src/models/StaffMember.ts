import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';
import User from './User';
import Business from './Business';
import EmailService from '../services/emailService';

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
  public readonly user?: User;
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

const resolveStaffNotificationContext = async (staffMember: StaffMember) => {
  const [business, staffUser] = await Promise.all([
    Business.findByPk(staffMember.businessId, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['fullName', 'firstName', 'email'],
        },
      ],
    }),
    User.findByPk(staffMember.userId, {
      attributes: ['fullName', 'firstName', 'lastName', 'email'],
    }),
  ]);

  if (!business) {
    return null;
  }

  const owner = (business as any).owner as User | undefined;
  const ownerEmail = owner?.email || business.email;
  if (!ownerEmail) {
    return null;
  }

  const ownerName = owner?.fullName || owner?.firstName || 'there';
  const staffName =
    staffUser?.fullName ||
    [staffUser?.firstName, staffUser?.lastName].filter(Boolean).join(' ') ||
    'New team member';

  return {
    ownerEmail,
    ownerName,
    businessName: business.businessName,
    staffName,
    staffEmail: staffUser?.email,
  };
};

StaffMember.addHook('afterCreate', async (staffMember: StaffMember) => {
  try {
    const context = await resolveStaffNotificationContext(staffMember);
    if (context) {
      await EmailService.sendBusinessStaffAdded({
        email: context.ownerEmail,
        ownerName: context.ownerName,
        businessName: context.businessName,
        staffName: context.staffName,
        staffEmail: context.staffEmail,
      });
    }
  } catch (error) {
    console.error('StaffMember afterCreate notification error:', error);
  }
});

StaffMember.addHook('afterDestroy', async (staffMember: StaffMember) => {
  try {
    const context = await resolveStaffNotificationContext(staffMember);
    if (context) {
      await EmailService.sendBusinessStaffRemoved({
        email: context.ownerEmail,
        ownerName: context.ownerName,
        businessName: context.businessName,
        staffName: context.staffName,
        staffEmail: context.staffEmail,
      });
    }
  } catch (error) {
    console.error('StaffMember afterDestroy notification error:', error);
  }
});

export default StaffMember;
