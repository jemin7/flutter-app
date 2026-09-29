const config = require('../config');

/** Wrap async route handlers so rejections hit the central handler. */
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function notFound(req, res) {
  res.status(404).json({ success: false, message: `Route not found: ${req.method} ${req.originalUrl}`, errors: null });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Safety net for duplicate username/email racing past the pre-check: unique index 11000 -> 409
  if (err.code === 11000 && err.keyValue) {
    const field = 'username' in err.keyValue ? 'username' : 'email';
    err.status = 409;
    err.message = field === 'username' ? 'Username already taken' : 'Email already registered';
    err.errors = { [field]: err.message };
  }
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({
    success: false,
    message: status >= 500 && config.env === 'production' ? 'Internal server error' : err.message || 'Internal server error',
    errors: err.errors || null,
    ...(err.code ? { code: err.code } : {}),
  });
}

module.exports = { asyncHandler, notFound, errorHandler };
