const express = require('express');
const mongoose = require('mongoose');
const { listUsers, updateUser, deleteUser } = require('../controllers/adminUsersController');
const { listCompanies } = require('../controllers/externalUsersController');
const { authenticate, authorize } = require('../middleware/auth');
const { ApiError } = require('../middleware/errors');

const router = express.Router();
router.use(authenticate, authorize('SUPER_ADMIN'));

// Spec: invalid ObjectId in admin routes -> 400
const validId = (req, res, next) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw new ApiError(400, 'Invalid user id');
  next();
};

router.get('/users', listUsers);
router.patch('/users/:id', validId, updateUser);
router.delete('/users/:id', validId, deleteUser);
router.get('/companies', listCompanies);

module.exports = router;
