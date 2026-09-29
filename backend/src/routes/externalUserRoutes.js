const express = require('express');
const { listExternalUsers, getExternalUser } = require('../controllers/externalUsersController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

router.get('/', listExternalUsers);
router.get('/:id', getExternalUser);

module.exports = router;
