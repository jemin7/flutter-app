const { body } = require('express-validator');

const passwordRules = (field = 'password') =>
  body(field)
    .isString().trim().notEmpty().withMessage(`${field} is required`)
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/[A-Z]/).withMessage('Password must contain an uppercase letter')
    .matches(/[a-z]/).withMessage('Password must contain a lowercase letter')
    .matches(/[0-9]/).withMessage('Password must contain a digit')
    .matches(/[^A-Za-z0-9]/).withMessage('Password must contain a special character');

const registerRules = [
  body('fullName').isString().trim().notEmpty().withMessage('Full name is required'),
  body('username')
    .isString().trim().notEmpty().withMessage('Username is required')
    .isLength({ min: 3, max: 20 }).withMessage('Username must be 3-20 characters')
    .matches(/^[a-zA-Z0-9_]+$/).withMessage('Username can only contain letters, numbers and underscore'),
  body('email').isString().trim().notEmpty().withMessage('Email is required').isEmail().withMessage('Invalid email address'),
  passwordRules(),
  body('confirmPassword').isString().trim().notEmpty().withMessage('Confirm password is required'),
];

const loginRules = [
  body('identifier').isString().trim().notEmpty().withMessage('Username or email is required'),
  passwordRules(),
];

const changePasswordRules = [passwordRules('currentPassword'), passwordRules('newPassword')];

module.exports = { registerRules, loginRules, changePasswordRules };
