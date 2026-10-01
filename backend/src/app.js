const express = require('express');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const { sanitizeBody, stripProtoKeys } = require('./middleware/auth');
const { notFound, errorHandler } = require('./middleware/errorHandler');

const authRoutes = require('./routes/authRoutes');
const externalUserRoutes = require('./routes/externalUserRoutes');
const adminRoutes = require('./routes/adminRoutes');
const settingsRoutes = require('./routes/settingsRoutes');
const reportRoutes = require('./routes/reportRoutes');

function createApp() {
  const app = express();

  // Behind Render's reverse proxy: express-rate-limit must trust X-Forwarded-For,
  // otherwise every client shares the proxy's IP and one global 100/15min bucket.
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '100kb' }));
  if (config.env !== 'test') app.use(morgan('dev'));

  app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 100, standardHeaders: true, legacyHeaders: false }));

  app.get('/api/health', (req, res) => res.json({ success: true, data: { status: 'ok', uptime: process.uptime() }, message: null, errors: null }));

  app.use('/api/auth', stripProtoKeys, sanitizeBody, authRoutes);
  app.use('/api/external-users', stripProtoKeys, sanitizeBody, externalUserRoutes);
  app.use('/api/admin', stripProtoKeys, sanitizeBody, adminRoutes);
  app.use('/api/settings', stripProtoKeys, sanitizeBody, settingsRoutes);
  app.use('/api/reports', stripProtoKeys, sanitizeBody, reportRoutes);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = createApp;
