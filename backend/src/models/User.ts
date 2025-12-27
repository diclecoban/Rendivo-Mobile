import { DataTypes, Model, Optional } from 'sequelize';
import sequelize from '../config/database';
import bcrypt from 'bcryptjs';

// User types
export enum UserRole {
  CUSTOMER = 'customer',
  STAFF = 'staff',
  BUSINESS_OWNER = 'business_owner',
  ADMIN = 'admin',
}

export enum AuthProvider {
  LOCAL = 'local',
  FIREBASE = 'firebase',
  GOOGLE = 'google',
  FACEBOOK = 'facebook',
  APPLE = 'apple'
}

// User attributes interface
export interface UserAttributes {
  id: number;
  email: string;
  password?: string;
  firstName?: string;
  lastName?: string;
  fullName?: string;
  phone?: string;
  role: UserRole;
  authProvider: AuthProvider;
  firebaseUid?: string;
  emailVerified: boolean;
  isActive: boolean;
  lastLogin?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

interface UserCreationAttributes extends Optional<UserAttributes, 'id' | 'emailVerified' | 'isActive'> {}

// User Model
class User extends Model<UserAttributes, UserCreationAttributes> implements UserAttributes {
  public id!: number;
  public email!: string;
  public password?: string;
  public firstName?: string;
  public lastName?: string;
  public fullName?: string;
  public phone?: string;
  public role!: UserRole;
  public authProvider!: AuthProvider;
  public firebaseUid?: string;
  public emailVerified!: boolean;
  public isActive!: boolean;
  public lastLogin?: Date;

  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  // Instance method to compare password
  public async comparePassword(candidatePassword: string): Promise<boolean> {
    if (!this.password) return false;
    return bcrypt.compare(candidatePassword, this.password);
  }

  // Instance method to get user without sensitive data
  public toSafeObject() {
    const { password, ...safeUser } = this.toJSON();
    return safeUser;
  }
}

User.init(
  {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      autoIncrement: true,
      primaryKey: true,
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true,
      },
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: true, // Nullable for OAuth users
    },
    firstName: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    lastName: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    fullName: {
      type: DataTypes.STRING(200),
      allowNull: true,
    },
    phone: {
      type: DataTypes.STRING(20),
      allowNull: true,
    },
    role: {
      type: DataTypes.ENUM(...Object.values(UserRole)),
      allowNull: false,
      defaultValue: UserRole.CUSTOMER,
    },
    authProvider: {
      type: DataTypes.ENUM(...Object.values(AuthProvider)),
      allowNull: false,
      defaultValue: AuthProvider.LOCAL,
    },
    firebaseUid: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
    },
    emailVerified: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    lastLogin: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    tableName: 'users',
    timestamps: true,
    hooks: {
      // Hash password before creating user
      beforeCreate: async (user: User) => {
        if (user.password) {
          const salt = await bcrypt.genSalt(10);
          user.password = await bcrypt.hash(user.password, salt);
        }
      },
      // Hash password before updating if password is modified
      beforeUpdate: async (user: User) => {
        if (user.changed('password') && user.password) {
          const salt = await bcrypt.genSalt(10);
          user.password = await bcrypt.hash(user.password, salt);
        }
      },
    },
  }
);

export default User;
