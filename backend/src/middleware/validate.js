const { validationResult } = require('express-validator');

function validate(req, res, next) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return next();
  const fieldErrors = {};
  for (const e of errors.array()) {
    const field = e.path || '_';
    if (!fieldErrors[field]) fieldErrors[field] = e.msg;
  }
  return res.status(400).json({ success: false, message: 'Validation failed', errors: fieldErrors });
}

module.exports = validate;
