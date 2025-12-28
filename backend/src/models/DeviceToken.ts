import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';

export interface DeviceTokenAttributes {
  id: number;
  userId: number;
  token: string;
  platform: string;
  createdAt?: Date;
  updatedAt?: Date;
}

interface DeviceTokenCreationAttributes
  extends Optional<DeviceTokenAttributes, 'id'> {}

class DeviceToken
  extends Model<DeviceTokenAttributes, DeviceTokenCreationAttributes>
  implements DeviceTokenAttributes
{
  public id!: number;
  public userId!: number;
  public token!: string;
  public platform!: string;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;
}

DeviceToken.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER.UNSIGNED,
      allowNull: false,
    },
    token: {
      type: DataTypes.STRING(512),
      allowNull: false,
      unique: true,
    },
    platform: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'android',
    },
  },
  {
    sequelize,
    tableName: 'device_tokens',
    timestamps: true,
  }
);

export default DeviceToken;
