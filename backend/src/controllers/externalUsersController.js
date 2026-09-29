const { fetchExternalUsers } = require('../services/externalApiService');
const { ApiError } = require('../middleware/errors');
const { asyncHandler } = require('../middleware/errorHandler');

const NO_COMPANY_MSG = 'No company assigned. Contact your administrator.';

function filterByCompany(users, user) {
  if (user.role === 'SUPER_ADMIN') return users;
  if (!user.companyName) return [];
  return users.filter((u) => u.company && u.company.name === user.companyName);
}

const listExternalUsers = asyncHandler(async (req, res) => {
  // Spec: users of other companies are "not accessible" — a USER whose company
  // yields nothing (none assigned, or no matches) gets 403, not a silent empty list.
  const visible = filterByCompany(await fetchExternalUsers(), req.user);
  if (req.user.role !== 'SUPER_ADMIN' && !visible.length) {
    throw new ApiError(403, req.user.companyName ? 'No users found for your company' : NO_COMPANY_MSG);
  }
  res.json({ success: true, data: visible, message: visible.length ? null : 'No users found', errors: null });
});

const getExternalUser = asyncHandler(async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) throw new ApiError(400, 'Invalid user id');
  const all = await fetchExternalUsers();
  const target = all.find((u) => String(u.id) === req.params.id);

  if (!target) throw new ApiError(404, 'User not found');

  if (req.user.role !== 'SUPER_ADMIN') {
    const userCompany = req.user.companyName;
    if (!userCompany || !target.company || target.company.name !== userCompany) {
      throw new ApiError(403, 'You do not have permission to view this user');
    }
  }

  res.json({ success: true, data: target, message: null, errors: null });
});

const listCompanies = asyncHandler(async (req, res) => {
  const all = await fetchExternalUsers();
  const companies = [...new Set(all.map((u) => u.company?.name).filter(Boolean))].sort();
  res.json({ success: true, data: companies, message: null, errors: null });
});

module.exports = { listExternalUsers, getExternalUser, listCompanies };
