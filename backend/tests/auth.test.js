const request = require('supertest');
const { setup, teardown, reset } = require('./helpers/db');

let app;
let createApp;
let User;

const ADMIN = { fullName: 'Super Admin', username: 'admin', email: 'admin@test.com', password: 'Admin@123', confirmPassword: 'Admin@123', role: 'SUPER_ADMIN', companyName: null };
const HEMANT = { fullName: 'Hemant Kumar', username: 'hemant', email: 'hemant@test.com', password: 'User@123', confirmPassword: 'User@123', role: 'USER', companyName: 'Romaguera-Crona' };

// JSONPlaceholder ids: 1 = Romaguera-Crona, 2 = Deckow-Crist, others different companies.
const OTHER_COMPANY_ID = '3';

async function register(body) {
  return request(app).post('/api/auth/register').send(body);
}

async function login(identifier, password) {
  return request(app).post('/api/auth/login').send({ identifier, password });
}

const authed = (token) => request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);

beforeAll(async () => {
  await setup();
  createApp = require('../src/app');
  app = createApp();
  User = require('../src/models/User');
});

afterAll(teardown);

describe('Auth: register', () => {
  const valid = { fullName: 'Test User', username: 'testuser', email: 'test@test.com', password: 'Passw0rd!', confirmPassword: 'Passw0rd!' };

  beforeEach(reset);

  it('registers a user as USER with no company, even if role/companyName are injected', async () => {
    const res = await register({ ...valid, role: 'SUPER_ADMIN', companyName: 'Romaguera-Crona' });
    expect(res.status).toBe(201);
    const doc = await User.findOne({ username: 'testuser' });
    expect(doc.role).toBe('USER');
    expect(doc.companyName).toBeNull();
  });

  it('rejects weak password, bad username, bad email', async () => {
    const res = await register({ ...valid, username: 'bad name!', email: 'nope', password: 'weak', confirmPassword: 'weak' });
    expect(res.status).toBe(400);
    expect(res.body.errors.username).toBeDefined();
    expect(res.body.errors.email).toBeDefined();
    expect(res.body.errors.password).toBeDefined();
  });

  it('rejects mismatched confirmPassword', async () => {
    const res = await register({ ...valid, confirmPassword: 'Different1!' });
    expect(res.status).toBe(400);
    expect(res.body.errors.confirmPassword).toBeDefined();
  });

  it('returns 409 with field-specific message for duplicate username', async () => {
    await register(valid);
    const res = await register({ ...valid, email: 'other@test.com' });
    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/username/i);
  });

  it('returns 409 for duplicate email (case-insensitive)', async () => {
    await register(valid);
    const res = await register({ ...valid, username: 'otheruser', email: 'TEST@TEST.COM' });
    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/email/i);
  });

  it('rejects NoSQL injection in register fields (objects where strings expected)', async () => {
    const res = await register({ fullName: { $gt: '' }, username: 'inj', email: 'inj@test.com', password: 'Passw0rd!', confirmPassword: 'Passw0rd!' });
    expect(res.status).toBe(400);
  });
});

describe('Auth: login', () => {
  beforeEach(async () => {
    await reset();
    await register(ADMIN);
    await register(HEMANT);
    await User.updateOne({ username: 'admin' }, { role: 'SUPER_ADMIN', companyName: null });
    await User.updateOne({ username: 'hemant' }, { companyName: 'Romaguera-Crona' });
  });

  it('logs in with email and returns token + profile + menu', async () => {
    const res = await login('admin@test.com', 'Admin@123');
    expect(res.status).toBe(200);
    expect(res.body.data.token).toBeDefined();
    expect(res.body.data.user.role).toBe('SUPER_ADMIN');
    expect(res.body.data.menu).toContain('user_management');
  });

  it('logs in with username (case-insensitive)', async () => {
    const res = await login('HEMANT', 'User@123');
    expect(res.status).toBe(200);
    expect(res.body.data.user.companyName).toBe('Romaguera-Crona');
  });

  it('gives one generic error for wrong identifier or wrong password', async () => {
    const wrongId = await login('nobody@test.com', 'User@123');
    const wrongPw = await login('hemant', 'WrongPass1!');
    for (const res of [wrongId, wrongPw]) {
      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Invalid username/email or password');
    }
  });

  it('rejects NoSQL injection on login (objects as identifier/password)', async () => {
    const res = await login({ $gt: '' }, { $gt: '' });
    expect(res.status).toBe(400);
  });

  it('rejects dot-notation keys in body', async () => {
    const res = await request(app).post('/api/auth/login').send({ 'identifier.x': 'a', password: 'User@123' });
    expect(res.status).toBe(400);
  });
});

describe('GET /api/auth/me', () => {
  let token;

  beforeEach(async () => {
    await reset();
    await register(HEMANT);
    await User.updateOne({ username: 'hemant' }, { companyName: 'Romaguera-Crona' });
    token = (await login('hemant', 'User@123')).body.data.token;
  });

  it('returns current user + menu for a valid token', async () => {
    const res = await authed(token);
    expect(res.status).toBe(200);
    expect(res.body.data.user.username).toBe('hemant');
    expect(res.body.data.menu).toEqual(['dashboard', 'users', 'settings']);
  });

  it('rejects a garbage token with TOKEN_INVALID', async () => {
    const res = await authed('garbage.token.here');
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('TOKEN_INVALID');
  });

  it('rejects an expired token with TOKEN_EXPIRED', async () => {
    const jwt = require('jsonwebtoken');
    const expired = jwt.sign({ sub: '000000000000000000000000', role: 'USER' }, process.env.JWT_SECRET, { expiresIn: '-10s' });
    const res = await authed(expired);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('TOKEN_EXPIRED');
  });

  it('rejects when no token is sent', async () => {
    expect((await request(app).get('/api/auth/me')).status).toBe(401);
  });
});

describe('GET /api/external-users (company filtering)', () => {
  let adminToken, hemantToken;

  beforeEach(async () => {
    await reset();
    await register(ADMIN);
    await register(HEMANT);
    await User.updateOne({ username: 'admin' }, { role: 'SUPER_ADMIN' });
    await User.updateOne({ username: 'hemant' }, { companyName: 'Romaguera-Crona' });
    adminToken = (await login('admin', 'Admin@123')).body.data.token;
    hemantToken = (await login('hemant', 'User@123')).body.data.token;
  });

  it('SUPER_ADMIN sees all users', async () => {
    const res = await request(app).get('/api/external-users').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(10);
  });

  it('USER sees only own company', async () => {
    const res = await request(app).get('/api/external-users').set('Authorization', `Bearer ${hemantToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.every((u) => u.company.name === 'Romaguera-Crona')).toBe(true);
  });

  it('USER with no company gets 403, not a silent empty list', async () => {
    await register({ fullName: 'No Co', username: 'noco', email: 'noco@test.com', password: 'User@123', confirmPassword: 'User@123' });
    const token = (await login('noco', 'User@123')).body.data.token;
    const res = await request(app).get('/api/external-users').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.message).toMatch(/No company assigned/);
  });

  it('blocks cross-company access by id with 403, even with a valid token', async () => {
    const res = await request(app).get(`/api/external-users/${OTHER_COMPANY_ID}`).set('Authorization', `Bearer ${hemantToken}`);
    expect(res.status).toBe(403);
  });

  it('allows own-company access by id', async () => {
    const res = await request(app).get('/api/external-users/1').set('Authorization', `Bearer ${hemantToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.company.name).toBe('Romaguera-Crona');
  });

  it('returns 400 for non-numeric id and 404 for unknown id', async () => {
    expect((await request(app).get('/api/external-users/abc').set('Authorization', `Bearer ${hemantToken}`)).status).toBe(400);
    expect((await request(app).get('/api/external-users/99999').set('Authorization', `Bearer ${adminToken}`)).status).toBe(404);
  });

  it('requires authentication', async () => {
    expect((await request(app).get('/api/external-users')).status).toBe(401);
  });
});

describe('Admin routes (SUPER_ADMIN only)', () => {
  let adminToken, hemantToken, hemantId;

  beforeEach(async () => {
    await reset();
    await register(ADMIN);
    await register(HEMANT);
    await User.updateOne({ username: 'admin' }, { role: 'SUPER_ADMIN' });
    adminToken = (await login('admin', 'Admin@123')).body.data.token;
    hemantToken = (await login('hemant', 'User@123')).body.data.token;
    hemantId = (await User.findOne({ username: 'hemant' }))._id.toString();
  });

  it('USER gets 403 on every admin route', async () => {
    const routes = [
      request(app).get('/api/admin/users'),
      request(app).patch(`/api/admin/users/${hemantId}`).send({ role: 'SUPER_ADMIN' }),
      request(app).delete(`/api/admin/users/${hemantId}`),
      request(app).get('/api/admin/companies'),
      request(app).get('/api/reports/summary'),
    ];
    for (const route of routes) {
      const res = await route.set('Authorization', `Bearer ${hemantToken}`);
      expect(res.status).toBe(403);
    }
  });

  it('SUPER_ADMIN lists and updates users', async () => {
    const res = await request(app).patch(`/api/admin/users/${hemantId}`).set('Authorization', `Bearer ${adminToken}`).send({ companyName: 'Deckow-Crist' });
    expect(res.status).toBe(200);
    expect(res.body.data.companyName).toBe('Deckow-Crist');
  });

  it('rejects invalid company name on update', async () => {
    const res = await request(app).patch(`/api/admin/users/${hemantId}`).set('Authorization', `Bearer ${adminToken}`).send({ companyName: 'Not-A-Real-Company' });
    expect(res.status).toBe(400);
  });

  it('admin cannot demote or delete self', async () => {
    const adminId = (await User.findOne({ username: 'admin' }))._id.toString();
    const demote = await request(app).patch(`/api/admin/users/${adminId}`).set('Authorization', `Bearer ${adminToken}`).send({ role: 'USER' });
    const del = await request(app).delete(`/api/admin/users/${adminId}`).set('Authorization', `Bearer ${adminToken}`);
    expect(demote.status).toBe(403);
    expect(del.status).toBe(403);
  });

  it('returns 400 for invalid ObjectId', async () => {
    const res = await request(app).delete('/api/admin/users/not-an-id').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(400);
  });
});
