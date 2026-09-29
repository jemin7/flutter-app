const User = require('../models/User');
const { ApiError } = require('../middleware/errors');
const { asyncHandler } = require('../middleware/errorHandler');
const { fetchExternalUsers } = require('../services/externalApiService');

const listUsers = asyncHandler(async (req, res) => {
  const users = await User.find().sort({ createdAt: -1 });
  res.json({ success: true, data: users, message: null, errors: null });
});

const updateUser = asyncHandler(async (req, res) => {
  const { role, companyName } = req.body;

  if (role !== undefined && !['USER', 'SUPER_ADMIN'].includes(role)) {
    throw new ApiError(400, 'Invalid role');
  }
  if (companyName !== undefined && companyName !== null) {
    const companies = await fetchExternalUsers();
    const valid = companies.some((u) => u.company && u.company.name === companyName);
    if (!valid) throw new ApiError(400, 'Invalid company name');
  }

  if (req.params.id === req.user.id) {
    if (role !== undefined && role !== 'SUPER_ADMIN') throw new ApiError(403, 'You cannot demote yourself');
  }

  const user = await User.findByIdAndUpdate(
    req.params.id,
    { $set: { ...(role !== undefined && { role }), ...(companyName !== undefined && { companyName }) } },
    { new: true, runValidators: true }
  );
  if (!user) throw new ApiError(404, 'User not found');

  res.json({ success: true, data: user, message: 'User updated', errors: null });
});

const deleteUser = asyncHandler(async (req, res) => {
  if (req.params.id === req.user.id) throw new ApiError(403, 'You cannot delete yourself');
  const user = await User.findByIdAndDelete(req.params.id);
  if (!user) throw new ApiError(404, 'User not found');
  res.json({ success: true, data: null, message: 'User deleted', errors: null });
});

module.exports = { listUsers, updateUser, deleteUser };
