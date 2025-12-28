import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';
import User from './User';

export interface UserDeviceTokenAttributes {
  id: number;
  userId: number;
  token: string;
  platform: string;
  lastSeenAt?: Date | null;
  createdAt?: Date;
  updatedAt?: Date;
}

interface UserDeviceTokenCreationAttributes
  extends Optional<UserDeviceTokenAttributes, 'id' | 'platform' | 'lastSeenAt'> {}

class UserDeviceToken
  extends Model<UserDeviceTokenAttributes, UserDeviceTokenCreationAttributes>
  implements UserDeviceTokenAttributes
{
  public id!: number;
  public userId!: number;
  public token!: string;
  public platform!: string;
  public lastSeenAt!: Date | null;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
  public readonly user?: User;
}

UserDeviceToken.init(
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
    token: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
    },
    platform: {
      type: DataTypes.STRING(50),
      allowNull: false,
      defaultValue: 'android',
    },
    lastSeenAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    tableName: 'user_device_tokens',
    timestamps: true,
  }
);

export default UserDeviceToken;
