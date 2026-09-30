const axios = require('axios');

// ponytail: module-level cache, 5-min TTL — swap for Redis only if multi-instance
const CACHE_TTL_MS = 5 * 60 * 1000;
let cache = { data: null, fetchedAt: 0 };

async function fetchExternalUsers() {
  if (cache.data && Date.now() - cache.fetchedAt < CACHE_TTL_MS) return cache.data;
  const res = await axios.get('https://jsonplaceholder.typicode.com/users', { timeout: 10_000 });
  cache = { data: res.data, fetchedAt: Date.now() };
  return cache.data;
}

module.exports = { fetchExternalUsers };
