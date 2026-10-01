const express = require('express');
const { register, login, me } = require('../controllers/authController');
const { listCompanies } = require('../controllers/externalUsersController');
const { authenticate } = require('../middleware/auth');
const { registerRules, loginRules } = require('../middleware/validators');
const validate = require('../middleware/validate');

const router = express.Router();

router.post('/register', registerRules, validate, register);
// Public: the register screen needs the selectable company list (names only).
router.get('/companies', listCompanies);
router.post('/login', loginRules, validate, login);
router.get('/me', authenticate, me);

module.exports = router;
