require('dotenv').config();
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { connectDB } = require('../config/db');
const User = require('../models/User');

const seedUsers = [
  { fullName: 'Super Admin', username: 'admin', email: 'admin@test.com', password: 'Admin@123', role: 'SUPER_ADMIN', companyName: null },
  { fullName: 'Hemant Kumar', username: 'hemant', email: 'hemant@test.com', password: 'User@123', role: 'USER', companyName: 'Romaguera-Crona' },
  { fullName: 'Priya Sharma', username: 'priya', email: 'priya@test.com', password: 'User@123', role: 'USER', companyName: 'Deckow-Crist' },
];

async function seed() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('MONGODB_URI is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }
  try {
    await connectDB(uri);
    await mongoose.connection.db.admin().command({ ping: 1 });

    for (const u of seedUsers) {
      const passwordHash = await bcrypt.hash(u.password, 10);
      await User.findOneAndUpdate(
        { $or: [{ username: u.username.toLowerCase(), email: u.email.toLowerCase() }] },
        { $set: { ...u, username: u.username.toLowerCase(), email: u.email.toLowerCase(), passwordHash } },
        { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true }
      );
    }
    console.log(`Seed complete: ${seedUsers.length} users upserted.`);
  } catch (err) {
    console.error('Seed failed:', err.message);
    console.error('Check: MONGODB_URI correct? Atlas Network Access allows your IP?');
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

seed();
