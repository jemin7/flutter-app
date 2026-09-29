const User = require('../models/User');
const { fetchExternalUsers } = require('../services/externalApiService');
const { asyncHandler } = require('../middleware/errorHandler');

const summary = asyncHandler(async (req, res) => {
  const [roleCounts, companyCounts, total, external] = await Promise.all([
    User.aggregate([{ $group: { _id: '$role', count: { $sum: 1 } } }]),
    User.aggregate([{ $match: { companyName: { $ne: null } } }, { $group: { _id: '$companyName', count: { $sum: 1 } } }, { $sort: { count: -1 } }]),
    User.countDocuments(),
    fetchExternalUsers(),
  ]);

  const externalByCompany = {};
  for (const u of external) {
    const name = u.company?.name;
    if (name) externalByCompany[name] = (externalByCompany[name] || 0) + 1;
  }

  const byRole = Object.fromEntries(roleCounts.map((r) => [r._id, r.count]));
  res.json({
    success: true,
    data: {
      totalUsers: total,
      byRole: { SUPER_ADMIN: byRole.SUPER_ADMIN || 0, USER: byRole.USER || 0 },
      appUsersByCompany: companyCounts.map((c) => ({ company: c._id, count: c.count })),
      externalUsersByCompany: Object.entries(externalByCompany).map(([company, count]) => ({ company, count })).sort((a, b) => b.count - a.count),
    },
    message: null,
    errors: null,
  });
});

module.exports = { summary };
