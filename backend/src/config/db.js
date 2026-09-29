const mongoose = require('mongoose');

async function connectDB(uri) {
  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 10000,
    socketTimeoutMS: 45000,
  });
  return mongoose.connection;
}

module.exports = { connectDB };
