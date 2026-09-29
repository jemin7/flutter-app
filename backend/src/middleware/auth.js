const config = require('../config');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

/** NoSQL-injection guard: everything that should be a string must BE a plain string. */
function sanitizeBody(req, res, next) {
  const clean = (val) => {
    if (Array.isArray(val)) return val.map(clean);
    if (val && typeof val === 'object') return undefined; // reject objects where strings expected
    return val;
  };
  for (const key of Object.keys(req.body || {})) {
    const v = clean(req.body[key]);
    if (v === undefined) {
      return res.status(400).json({ success: false, message: `Field "${key}" must be a plain string`, errors: null });
    }
    req.body[key] = v;
  }
  next();
}

/** Reject keys starting with '$' or containing '.' anywhere in body/query. */
function stripProtoKeys(req, res, next) {
  const bad = (obj) => {
    if (!obj || typeof obj !== 'object') return false;
    return Object.keys(obj).some((k) => k.startsWith('$') || k.includes('.') || bad(obj[k]));
  };
  if (bad(req.body) || bad(req.query)) {
    return res.status(400).json({ success: false, message: 'Invalid characters in request', errors: null });
  }
  next();
}

function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ success: false, code: 'TOKEN_INVALID', message: 'Authentication required', errors: null });
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch (err) {
    const code = err.name === 'TokenExpiredError' ? 'TOKEN_EXPIRED' : 'TOKEN_INVALID';
    return res.status(401).json({ success: false, code, message: code === 'TOKEN_EXPIRED' ? 'Session expired, please log in again' : 'Invalid token', errors: null });
  }
  User.findById(payload.sub).select(User.PUBLIC_FIELDS)
    .then((user) => {
      if (!user) return res.status(401).json({ success: false, code: 'TOKEN_INVALID', message: 'User no longer exists', errors: null });
      req.user = user;
      next();
    })
    .catch(next);
}

function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ success: false, message: 'Authentication required', errors: null });
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'You do not have permission to perform this action', errors: null });
    }
    next();
  };
}

module.exports = { sanitizeBody, stripProtoKeys, authenticate, authorize };
