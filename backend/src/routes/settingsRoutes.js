const express = require('express');
const { getProfile, updateProfile, changePassword } = require('../controllers/settingsController');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { changePasswordRules } = require('../middleware/validators');
const { body } = require('express-validator');

const router = express.Router();
router.use(authenticate);

router.get('/profile', getProfile);
router.patch('/profile', body('fullName').isString().trim().notEmpty().withMessage('Full name is required'), validate, updateProfile);
router.post('/change-password', changePasswordRules, validate, changePassword);

module.exports = router;
