const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { ApiError } = require('../middleware/errors');
const { asyncHandler } = require('../middleware/errorHandler');

const getProfile = asyncHandler(async (req, res) => {
  res.json({ success: true, data: { user: req.user }, message: null, errors: null });
});

const updateProfile = asyncHandler(async (req, res) => {
  const { fullName } = req.body;
  if (!fullName || !String(fullName).trim()) throw new ApiError(400, 'Validation failed', { fullName: 'Full name is required' });

  const user = await User.findByIdAndUpdate(req.user._id, { $set: { fullName: String(fullName).trim() } }, { new: true, runValidators: true });
  res.json({ success: true, data: { user }, message: 'Profile updated', errors: null });
});

const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  const user = await User.findById(req.user._id).select('+passwordHash');
  const ok = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!ok) throw new ApiError(400, 'Validation failed', { currentPassword: 'Current password is incorrect' });

  user.passwordHash = await bcrypt.hash(newPassword, 10);
  await user.save();

  res.json({ success: true, data: null, message: 'Password changed successfully', errors: null });
});

module.exports = { getProfile, updateProfile, changePassword };
