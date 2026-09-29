const express = require('express');
const { summary } = require('../controllers/reportsController');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

router.get('/summary', authenticate, authorize('SUPER_ADMIN'), summary);

module.exports = router;
