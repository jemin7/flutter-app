require('dotenv').config({ path: '.env.test' });
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;

module.exports = {
  async setup() {
    mongo = await MongoMemoryServer.create();
    process.env.MONGODB_URI = mongo.getUri('assignment_test');
    await mongoose.connect(process.env.MONGODB_URI);
    await mongoose.connection.db.dropDatabase();
    return mongoose.connection;
  },
  async teardown() {
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  },
  async reset() {
    const collections = await mongoose.connection.db.collections();
    for (const c of collections) await c.deleteMany({});
  },
};
