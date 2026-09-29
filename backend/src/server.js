require('./config'); // exits early if required env vars are missing
const app = require('./app')(); // app.js exports the createApp factory — instantiate it
const config = require('./config');
const { connectDB } = require('./config/db');
const mongoose = require('mongoose');
const User = require('./models/User');

async function main() {
  try {
    const connection = await connectDB(config.mongoUri);
    await User.syncIndexes();
    console.log(`MongoDB connected: ${connection.name}`);

    const server = app.listen(config.port, () => console.log(`API listening on http://localhost:${config.port}`));

    const shutdown = async (signal) => {
      console.log(`\n${signal} received, shutting down...`);
      server.close();
      await mongoose.disconnect();
      process.exit(0);
    };
    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (err) {
    console.error('Failed to start server:', err.message);
    console.error('Check: 1) MONGODB_URI correct? 2) Atlas credentials valid? 3) Atlas Network Access includes your IP (or 0.0.0.0/0 for Render).');
    process.exit(1);
  }
}

main();
