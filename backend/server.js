require('dotenv').config();

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'changeme';
const BUSINESS_DAY_START = process.env.BUSINESS_DAY_START || '09:00';
const BUSINESS_DAY_END = process.env.BUSINESS_DAY_END || '18:00';
const DEFAULT_SLOT_MINUTES = Number(process.env.DEFAULT_SLOT_MINUTES || 30);

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
});

const allowedOrigins = process.env.FRONTEND_URL
  ? process.env.FRONTEND_URL.split(',').map((v) => v.trim())
  : undefined;

app.use(
  cors({
    origin: allowedOrigins || true, // reflect request origin if not provided
    credentials: true,
  })
);
app.use(express.json());

function redactSensitive(body) {
  if (!body || typeof body !== 'object') return body;
  const copy = Array.isArray(body) ? [...body] : { ...body };
  if (copy.password) copy.password = '[redacted]';
  if (copy.newPassword) copy.newPassword = '[redacted]';
  return copy;
}

// Log incoming non-GET requests to see payloads coming from the frontend
app.use((req, _res, next) => {
  if (req.method !== 'GET') {
    console.log(`[request] ${req.method} ${req.originalUrl}`, redactSensitive(req.body));
  }
  next();
});

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ message: 'Unauthorized' });
  const token = header.replace('Bearer ', '');
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Invalid token' });
  }
}

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, firstName, lastName = '', phone = '' } = req.body;
    if (!email || !password || !firstName) {
      return res.status(400).json({ message: 'email, password, firstName are required' });
    }

    const [exists] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (exists.length) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const fullName = `${firstName} ${lastName}`.trim();

    const [result] = await pool.execute(
      `INSERT INTO users
        (email, password, firstName, lastName, fullName, phone, role, authProvider, emailVerified, isActive, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, 'customer', 'local', 0, 1, NOW(), NOW())`,
      [email, hashed, firstName, lastName, fullName, phone]
    );

    const token = jwt.sign(
      { id: result.insertId, email, role: 'customer' },
      JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      token,
      user: { id: result.insertId, email, fullName, role: 'customer', phone },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Registration failed' });
  }
});

app.post('/api/auth/register-business', async (req, res) => {
  const connection = await pool.getConnection();

  try {
    const {
      fullName,
      email,
      password,
      businessName,
      businessType = '',
      phone = '',
      publicEmail = '',
      street = '',
      city = '',
      state = '',
      postalCode = '',
      description = '',
      country = '',
      website = '',
      // logo istersen body'den gelebilir
      logo = '',
    } = req.body;

    // Zorunlu alan kontrolü
    if (!fullName || !email || !password || !businessName) {
      return res.status(400).json({
        message: 'fullName, email, password, businessName are required',
      });
    }

    // Email zaten kayıtlı mı?
    const [existing] = await connection.query(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );

    if (existing.length > 0) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    await connection.beginTransaction();

    // Şifreyi hashle
    const hashed = await bcrypt.hash(password, 10);

    // fullName'i firstName / lastName'e kaba şekilde ayır
    const nameParts = fullName.trim().split(' ');
    const firstName = nameParts[0] || '';
    const lastName = nameParts.slice(1).join(' ') || '';

    // 1) USERS tablosuna owner user ekle
    const [userResult] = await connection.execute(
      `INSERT INTO users
        (email, password, firstName, lastName, fullName, phone, role, authProvider, emailVerified, isActive, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, 'business_owner', 'local', 0, 1, NOW(), NOW())`,
      [email, hashed, firstName, lastName, fullName, phone]
    );

    const ownerId = userResult.insertId;

    // 2) Business için benzersiz businessId üret (public ID gibi)
    const businessId = `BIZ-${ownerId}-${Date.now()}`;

    // 3) BUSINESSES tablosuna ekle
    // Kolon sırası şemanla uyumlu:
    // id, ownerId, businessName, businessType, description,
    // address, city, state, zipCode, country,
    // phone, email, website, logo, businessId,
    // isActive, createdAt, updatedAt
    const [businessResult] = await connection.execute(
      `INSERT INTO businesses
        (ownerId, businessName, businessType, description,
         address, city, state, zipCode, country,
         phone, email, website, logo, businessId,
         isActive, createdAt, updatedAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), NOW())`,
      [
        ownerId,
        businessName,
        businessType,
        description,
        street,
        city,
        state,
        postalCode,
        country,
        phone,
        publicEmail || email,
        website,
        logo,
        businessId,
      ]
    );

    const createdBusinessId = businessResult.insertId;

    // 4) Owner'ı staff_members tablosuna da kaydet (opsiyonel ama mantıklı)
    // staff_members:
    // id, userId, businessId, position, isActive, joinedAt, createdAt, updatedAt
    await connection.execute(
      `INSERT INTO staff_members
        (userId, businessId, position, isActive, joinedAt, createdAt, updatedAt)
       VALUES (?, ?, ?, 1, NOW(), NOW(), NOW())`,
      [ownerId, createdBusinessId, 'Owner']
    );

    await connection.commit();

    // JWT token
    const token = jwt.sign(
      { id: ownerId, email, role: 'business_owner' },
      JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      token,
      user: {
        id: ownerId,
        email,
        fullName,
        firstName,
        lastName,
        phone,
        role: 'business_owner',
      },
      business: {
        id: createdBusinessId,
        ownerId,
        businessId,
        businessName,
        businessType,
        description,
        address: street,
        city,
        state,
        zipCode: postalCode,
        country,
        phone,
        email: publicEmail || email,
        website,
        logo,
        isActive: 1,
      },
    });
  } catch (err) {
    try {
      await connection.rollback();
    } catch (_) {}
    console.error(err);
    res.status(500).json({ message: 'Business registration failed' });
  } finally {
    connection.release();
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'email and password are required' });
    }

    const [rows] = await pool.query(
      'SELECT id, email, password, fullName, role FROM users WHERE email = ? AND isActive = 1 LIMIT 1',
      [email]
    );
    if (!rows.length) {
      return res.status(404).json({ message: 'Account not found' });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });

    await pool.query('UPDATE users SET lastLogin = NOW() WHERE id = ?', [user.id]);

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Login failed' });
  }
});

app.get('/api/businesses', async (_req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT 
        b.*,
        u.fullName AS ownerName,
        JSON_ARRAYAGG(
          CASE 
            WHEN s.id IS NULL THEN NULL 
            ELSE JSON_OBJECT(
              'id', s.id,
              'name', s.name,
              'price', s.price,
              'duration', s.duration,
              'description', s.description
            )
          END
        ) AS servicesJson
       FROM businesses b
       LEFT JOIN users u ON b.ownerId = u.id
       LEFT JOIN services s ON s.businessId = b.id AND s.isActive = 1
       WHERE b.isActive = 1
       GROUP BY b.id`
    );

    const mapped = rows.map((row) => {
      let services = [];
      try {
        if (row.servicesJson) {
          const parsed = Array.isArray(row.servicesJson)
            ? row.servicesJson
            : JSON.parse(row.servicesJson);
          services = Array.isArray(parsed)
            ? parsed.filter((item) => item !== null).slice(0, 5)
            : [];
        }
      } catch (_) {
        services = [];
      }

      return { ...row, services };
    });

    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load businesses' });
  }
});

app.get('/api/businesses/me', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'business_owner') {
      return res.status(403).json({ message: 'Business owner access only' });
    }

    const [rows] = await pool.query(
      `SELECT 
         b.*,
         (
           SELECT JSON_ARRAYAGG(
             JSON_OBJECT(
               'id', s.id,
               'name', s.name,
               'price', s.price,
               'duration', s.duration,
               'description', s.description
             )
           )
           FROM services s
           WHERE s.businessId = b.id AND s.isActive = 1
         ) AS servicesJson,
         (
           SELECT JSON_ARRAYAGG(
             JSON_OBJECT(
               'id', sm.id,
               'name', COALESCE(u.fullName, ''),
               'role', COALESCE(sm.position, '')
             )
           )
           FROM staff_members sm
           LEFT JOIN users u ON sm.userId = u.id
           WHERE sm.businessId = b.id AND sm.isActive = 1
         ) AS staffJson
       FROM businesses b
       WHERE b.ownerId = ?
         AND b.isActive = 1
       ORDER BY b.createdAt DESC`,
      [req.user.id]
    );

    const parseJsonArray = (value) => {
      if (!value) return [];
      try {
        if (Array.isArray(value)) return value;
        if (typeof value === 'string') return JSON.parse(value);
        if (Buffer.isBuffer(value)) return JSON.parse(value.toString());
        return value;
      } catch (_) {
        return [];
      }
    };

    const mapped = rows.map((row) => {
      let services = [];
      services = parseJsonArray(row.servicesJson);

      let staff = [];
      staff = parseJsonArray(row.staffJson);

      return {
        ...row,
        services: Array.isArray(services)
          ? services.filter((item) => item !== null)
          : [],
        staff: Array.isArray(staff)
          ? staff.filter((item) => item !== null)
          : [],
      };
    });

    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load owner businesses' });
  }
});

app.get('/api/businesses/:id/services', async (req, res) => {
  try {
    const businessId = Number(req.params.id);
    if (Number.isNaN(businessId)) return res.status(400).json({ message: 'Invalid business id' });

    const [rows] = await pool.query(
      'SELECT * FROM services WHERE businessId = ? AND isActive = 1',
      [businessId]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load services' });
  }
});

function parseTimeToMinutes(value) {
  if (!value) return null;
  const parts = value.split(':').map((part) => Number(part));
  if (parts.length < 2 || parts.some((n) => Number.isNaN(n))) return null;
  const [hours, minutes] = parts;
  return hours * 60 + minutes;
}

function minutesToTime(value) {
  const hours = Math.floor(value / 60);
  const minutes = value % 60;
  const pad = (num) => num.toString().padStart(2, '0');
  return `${pad(hours)}:${pad(minutes)}:00`;
}

app.get('/api/businesses/:id/availability', async (req, res) => {
  try {
    const businessId = Number(req.params.id);
    if (Number.isNaN(businessId)) {
      return res.status(400).json({ message: 'Invalid business id' });
    }

    const dateStr =
      typeof req.query.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.date)
        ? req.query.date
        : new Date().toISOString().slice(0, 10);

    const requestedDuration = Number(req.query.durationMinutes);
    const durationMinutes =
      Number.isFinite(requestedDuration) && requestedDuration > 0
        ? requestedDuration
        : DEFAULT_SLOT_MINUTES;

    const slotMinutesParam = Number(req.query.slotMinutes);
    const slotMinutes =
      Number.isFinite(slotMinutesParam) && slotMinutesParam > 0
        ? slotMinutesParam
        : DEFAULT_SLOT_MINUTES;

    const dayStartMinutes = parseTimeToMinutes(BUSINESS_DAY_START);
    const dayEndMinutes = parseTimeToMinutes(BUSINESS_DAY_END);
    if (
      dayStartMinutes === null ||
      dayEndMinutes === null ||
      dayEndMinutes <= dayStartMinutes
    ) {
      return res.status(500).json({ message: 'Invalid business hours configuration' });
    }

    const [rows] = await pool.query(
      `SELECT startTime, endTime
         FROM appointments
        WHERE businessId = ?
          AND appointmentDate = ?
          AND status <> 'cancelled'`,
      [businessId, dateStr]
    );

    const busyBlocks = rows.map((row) => {
      const start = parseTimeToMinutes(row.startTime);
      const end = parseTimeToMinutes(row.endTime);
      return {
        start,
        end,
      };
    });

    function overlaps(start, end) {
      return busyBlocks.some((block) => {
        if (block.start === null || block.end === null) return false;
        return start < block.end && end > block.start;
      });
    }

    const slots = [];
    for (
      let cursor = dayStartMinutes;
      cursor + durationMinutes <= dayEndMinutes;
      cursor += slotMinutes
    ) {
      const slotEnd = cursor + durationMinutes;
      if (!overlaps(cursor, slotEnd)) {
        const startIso = `${dateStr}T${minutesToTime(cursor)}`;
        const endIso = `${dateStr}T${minutesToTime(slotEnd)}`;
        slots.push({
          startAt: startIso,
          endAt: endIso,
        });
      }
    }

    res.json({
      date: dateStr,
      slotMinutes,
      durationMinutes,
      slots,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load availability' });
  }
});

app.get('/api/customer/dashboard', authMiddleware, async (req, res) => {
  try {
    const customerId = req.user.id;

    const [
      [totalRows],
      [upcomingRows],
      [nextRows],
    ] = await Promise.all([
      pool.query(
        'SELECT COUNT(*) AS total FROM appointments WHERE customerId = ?',
        [customerId]
      ),
      pool.query(
        `SELECT COUNT(*) AS upcoming
         FROM appointments
         WHERE customerId = ?
           AND status <> 'cancelled'
           AND CONCAT(appointmentDate, ' ', startTime) >= NOW()`,
        [customerId]
      ),
      pool.query(
        `SELECT 
           a.id,
           a.businessId,
           b.businessName,
           a.appointmentDate,
           a.startTime,
           a.endTime,
           a.status,
           JSON_ARRAYAGG(
             CASE 
               WHEN sv.id IS NULL THEN NULL
               ELSE JSON_OBJECT(
                 'id', sv.id,
                 'name', sv.name
               )
             END
           ) AS servicesJson
         FROM appointments a
         LEFT JOIN businesses b ON a.businessId = b.id
         LEFT JOIN appointment_services aps ON aps.appointmentId = a.id
         LEFT JOIN services sv ON sv.id = aps.serviceId
         WHERE a.customerId = ?
           AND a.status <> 'cancelled'
           AND CONCAT(a.appointmentDate, ' ', a.startTime) >= NOW()
         GROUP BY a.id
         ORDER BY a.appointmentDate ASC, a.startTime ASC
         LIMIT 1`,
        [customerId]
      ),
    ]);

    const totalBookings = totalRows.length ? Number(totalRows[0].total) : 0;
    const upcomingCount = upcomingRows.length ? Number(upcomingRows[0].upcoming) : 0;

    let nextAppointment = null;
    if (nextRows.length) {
      const row = nextRows[0];
      let services = [];
      try {
        const raw = row.servicesJson;
        if (raw) {
          const parsed = Array.isArray(raw)
            ? raw
            : JSON.parse(typeof raw === 'string' ? raw : raw.toString());
          services = Array.isArray(parsed)
            ? parsed.filter((item) => item !== null)
            : [];
        }
      } catch (_) {
        services = [];
      }

      const firstServiceName = services.find((svc) => svc && svc.name)?.name;
      const title = firstServiceName || row.businessName || 'Upcoming appointment';

      const toIsoString = (dateStr, timeStr) => {
        if (!dateStr || !timeStr) return null;
        const isoCandidate = `${dateStr}T${timeStr}`;
        const parsed = new Date(isoCandidate);
        return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
      };

      nextAppointment = {
        id: row.id,
        businessId: row.businessId,
        businessName: row.businessName,
        title,
        status: row.status,
        startAt: toIsoString(row.appointmentDate, row.startTime),
        endAt: toIsoString(row.appointmentDate, row.endTime),
      };
    }

    res.json({
      totalBookings,
      upcomingCount,
      nextAppointment,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load customer dashboard' });
  }
});

app.get('/api/appointments/me', authMiddleware, async (req, res) => {
  try {
    const customerId = req.user.id;
    const [rows] = await pool.query(
      `SELECT 
          a.*,
          b.businessName,
          u.fullName AS customerName,
          u.email AS customerEmail,
          s.position AS staffPosition,
          JSON_ARRAYAGG(
            CASE 
              WHEN sv.id IS NULL THEN NULL
              ELSE JSON_OBJECT(
                'id', sv.id,
                'name', sv.name,
                'price', sv.price,
                'duration', sv.duration,
                'description', sv.description
              )
            END
          ) AS servicesJson
       FROM appointments a
       LEFT JOIN businesses b ON a.businessId = b.id
       LEFT JOIN users u ON a.customerId = u.id
       LEFT JOIN staff_members s ON a.staffId = s.id
       LEFT JOIN appointment_services aps ON aps.appointmentId = a.id
       LEFT JOIN services sv ON sv.id = aps.serviceId
       WHERE a.customerId = ?
       GROUP BY a.id
       ORDER BY a.appointmentDate DESC, a.startTime DESC`,
    [customerId]
    );
    const mapped = rows.map((row) => {
      let services = [];
      try {
        if (row.servicesJson) {
          const parsed = Array.isArray(row.servicesJson)
            ? row.servicesJson
            : JSON.parse(row.servicesJson);
          services = Array.isArray(parsed)
            ? parsed.filter((item) => item !== null)
            : [];
        }
      } catch (_) {
        services = [];
      }

      return { ...row, services };
    });

    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load appointments' });
  }
});

app.get('/api/staff/appointments', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'staff' && req.user.role !== 'business_owner') {
      return res.status(403).json({ message: 'Staff access only' });
    }

    let staffMemberId;

    if (req.user.role === 'staff') {
      const [staffRows] = await pool.query(
        'SELECT id FROM staff_members WHERE userId = ? AND isActive = 1 LIMIT 1',
        [req.user.id]
      );

      if (!staffRows.length) {
        return res.status(404).json({ message: 'Staff profile not found' });
      }
      staffMemberId = staffRows[0].id;
    } else {
      const requestedStaffId = Number(req.query.staffId);
      if (Number.isFinite(requestedStaffId)) {
        const [rows] = await pool.query(
          `SELECT sm.id
             FROM staff_members sm
             JOIN businesses b ON sm.businessId = b.id
            WHERE sm.id = ?
              AND b.ownerId = ?
              AND sm.isActive = 1
            LIMIT 1`,
          [requestedStaffId, req.user.id]
        );
        if (!rows.length) {
          return res
            .status(404)
            .json({ message: 'Staff member not found for this owner.' });
        }
        staffMemberId = rows[0].id;
      } else {
        const [rows] = await pool.query(
          `SELECT sm.id
             FROM staff_members sm
             JOIN businesses b ON sm.businessId = b.id
            WHERE b.ownerId = ?
              AND sm.isActive = 1
            ORDER BY sm.joinedAt ASC, sm.id ASC
            LIMIT 1`,
          [req.user.id]
        );

        if (!rows.length) {
          return res
            .status(404)
            .json({ message: 'No staff found for this owner.' });
        }
        staffMemberId = rows[0].id;
      }
    }

    const [rows] = await pool.query(
      `SELECT 
          a.*,
          b.businessName,
          u.fullName AS customerName,
          u.email AS customerEmail,
          JSON_ARRAYAGG(
            CASE 
              WHEN sv.id IS NULL THEN NULL
              ELSE JSON_OBJECT(
                'id', sv.id,
                'name', sv.name,
                'price', sv.price,
                'duration', sv.duration,
                'description', sv.description
              )
            END
          ) AS servicesJson
       FROM appointments a
       LEFT JOIN businesses b ON a.businessId = b.id
       LEFT JOIN users u ON a.customerId = u.id
       LEFT JOIN appointment_services aps ON aps.appointmentId = a.id
       LEFT JOIN services sv ON sv.id = aps.serviceId
       WHERE a.staffId = ?
       GROUP BY a.id
       ORDER BY a.appointmentDate DESC, a.startTime DESC`,
      [staffMemberId]
    );

    const mapped = rows.map((row) => {
      let services = [];
      try {
        if (row.servicesJson) {
          const parsed = Array.isArray(row.servicesJson)
            ? row.servicesJson
            : JSON.parse(row.servicesJson);
          services = Array.isArray(parsed)
            ? parsed.filter((item) => item !== null)
            : [];
        }
      } catch (_) {
        services = [];
      }

      return { ...row, services };
    });

    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not load staff appointments' });
  }
});

app.post('/api/appointments', authMiddleware, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { businessId, staffId, serviceIds, appointmentDate, startTime, endTime, notes = '' } =
      req.body;
    if (!businessId || !Array.isArray(serviceIds) || !serviceIds.length || !appointmentDate || !startTime || !endTime) {
      return res.status(400).json({ message: 'businessId, serviceIds, appointmentDate, startTime, endTime are required' });
    }

    const [services] = await connection.query(
      `SELECT id, price, duration FROM services WHERE id IN (${serviceIds.map(() => '?').join(',')}) AND isActive = 1`,
      serviceIds
    );
    if (!services.length) {
      return res.status(400).json({ message: 'No valid services provided' });
    }

    const totalPrice = services.reduce((sum, s) => sum + Number(s.price), 0);
    const totalDuration = services.reduce((sum, s) => sum + Number(s.duration), 0);

    await connection.beginTransaction();

    const [result] = await connection.execute(
      `INSERT INTO appointments
        (customerId, businessId, staffId, appointmentDate, startTime, endTime, totalPrice, totalDuration, status, notes, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, NOW(), NOW())`,
      [
        req.user.id,
        businessId,
        staffId || null,
        appointmentDate,
        startTime,
        endTime,
        totalPrice,
        totalDuration,
        notes,
      ]
    );

    const appointmentId = result.insertId;
    const values = serviceIds.map((id) => [appointmentId, id, new Date(), new Date()]);
    await connection.query(
      'INSERT INTO appointment_services (appointmentId, serviceId, createdAt, updatedAt) VALUES ?',
      [values]
    );

    await connection.commit();
    res.status(201).json({ appointmentId, totalPrice, totalDuration, status: 'pending' });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ message: 'Could not create appointment' });
  } finally {
    connection.release();
  }
});

app.patch('/api/appointments/:id/cancel', authMiddleware, async (req, res) => {
  try {
    const appointmentId = Number(req.params.id);
    if (Number.isNaN(appointmentId)) {
      return res.status(400).json({ message: 'Invalid appointment id' });
    }

    const [result] = await pool.execute(
      `UPDATE appointments 
       SET status = 'cancelled', updatedAt = NOW() 
       WHERE id = ? AND customerId = ?`,
      [appointmentId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    res.json({ status: 'cancelled' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not cancel appointment' });
  }
});

app.patch('/api/appointments/:id/reschedule', authMiddleware, async (req, res) => {
  try {
    const appointmentId = Number(req.params.id);
    const { startAt, endAt } = req.body;

    if (Number.isNaN(appointmentId) || !startAt || !endAt) {
      return res
        .status(400)
        .json({ message: 'appointment id, startAt and endAt are required' });
    }

    const start = new Date(startAt);
    const end = new Date(endAt);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      return res.status(400).json({ message: 'Invalid date values' });
    }

    const appointmentDate = start.toISOString().slice(0, 10);
    const startTime = start.toTimeString().slice(0, 8);
    const endTime = end.toTimeString().slice(0, 8);

    const [result] = await pool.execute(
      `UPDATE appointments 
       SET appointmentDate = ?, startTime = ?, endTime = ?, status = 'pending', updatedAt = NOW()
       WHERE id = ? AND customerId = ?`,
      [appointmentDate, startTime, endTime, appointmentId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    res.json({ status: 'pending', appointmentDate, startTime, endTime });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not reschedule appointment' });
  }
});

app.patch('/api/appointments/:id/notes', authMiddleware, async (req, res) => {
  try {
    const appointmentId = Number(req.params.id);
    const { notes = '' } = req.body;
    if (Number.isNaN(appointmentId)) {
      return res.status(400).json({ message: 'Invalid appointment id' });
    }

    const [result] = await pool.execute(
      `UPDATE appointments 
       SET notes = ?, updatedAt = NOW()
       WHERE id = ? AND customerId = ?`,
      [notes, appointmentId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Appointment not found' });
    }

    res.json({ notes });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Could not update notes' });
  }
});

app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}`);
});
