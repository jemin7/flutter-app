const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, required: true, trim: true },
    username: { type: String, required: true, unique: true, lowercase: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true, select: false },
    role: { type: String, enum: ['SUPER_ADMIN', 'USER'], default: 'USER' },
    companyName: { type: String, default: null },
  },
  { timestamps: true, toJSON: { transform: (_doc, ret) => { delete ret.passwordHash; delete ret.__v; ret.id = ret._id.toString(); delete ret._id; return ret; } } }
);

// ponytail: single shared projection — app profile + token payload use the same fields
userSchema.statics.PUBLIC_FIELDS = 'fullName username email role companyName';

module.exports = mongoose.model('User', userSchema);
