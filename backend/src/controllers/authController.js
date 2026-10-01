const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { signToken } = require('../services/tokenService');
const { fetchExternalUsers } = require('../services/externalApiService');
const { ApiError } = require('../middleware/errors');
const { asyncHandler } = require('../middleware/errorHandler');

const MENUS = {
  USER: ['dashboard', 'users', 'settings'],
  SUPER_ADMIN: ['dashboard', 'users', 'reports', 'user_management', 'settings'],
};

const menuFor = (role) => MENUS[role] || MENUS.USER;

function profilePayload(user) {
  return {
    user: {
      id: user._id.toString(),
      fullName: user.fullName,
      username: user.username,
      email: user.email,
      role: user.role,
      companyName: user.companyName,
    },
    menu: menuFor(user.role),
  };
}

const register = asyncHandler(async (req, res) => {
  const { fullName, username, email, password, confirmPassword, companyName } = req.body;

  if (password !== confirmPassword) {
    throw new ApiError(400, 'Validation failed', { confirmPassword: 'Passwords do not match' });
  }

  const normUsername = String(username).toLowerCase();
  const normEmail = String(email).toLowerCase();

  const existing = await User.findOne({ $or: [{ username: normUsername }, { email: normEmail }] }).collation({ locale: 'en', strength: 2 });
  if (existing) {
    const field = existing.username === normUsername ? 'username' : 'email';
    throw new ApiError(409, field === 'username' ? 'Username already taken' : 'Email already registered', {
      [field]: field === 'username' ? 'Username already taken' : 'Email already registered',
    });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  // Company is user-chosen but must exist in the external directory — same check
  // the admin endpoint uses — so nobody can register into an arbitrary company.
  // Role stays hard-coded: register can never create an admin.
  let assignedCompany = null;
  if (companyName !== undefined && companyName !== null && String(companyName).trim() !== '') {
    const companies = await fetchExternalUsers();
    const valid = companies.some((u) => u.company && u.company.name === companyName);
    if (!valid) throw new ApiError(400, 'Validation failed', { companyName: 'Invalid company name' });
    assignedCompany = companyName;
  }

  await User.create({ fullName, username: normUsername, email: normEmail, passwordHash, role: 'USER', companyName: assignedCompany });

  res.status(201).json({ success: true, data: null, message: 'Registration successful. Please log in.', errors: null });
});

const login = asyncHandler(async (req, res) => {
  const { identifier, password } = req.body;
  const id = String(identifier).toLowerCase();

  const user = await User.findOne({ $or: [{ email: id }, { username: id }] }).select('+passwordHash');
  // Same generic message whether identifier or password is wrong.
  const ok = user ? await bcrypt.compare(password, user.passwordHash) : false;
  if (!ok) throw new ApiError(401, 'Invalid username/email or password');

  const token = signToken(user);
  res.json({ success: true, data: { token, ...profilePayload(user) }, message: 'Login successful', errors: null });
});

const me = asyncHandler(async (req, res) => {
  res.json({ success: true, data: profilePayload(req.user), message: null, errors: null });
});

module.exports = { register, login, me, menuFor, profilePayload };
