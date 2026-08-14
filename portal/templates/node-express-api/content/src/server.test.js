const { test } = require('node:test');
const assert = require('node:assert');
const { createApp } = require('./app');

test('GET / returns service name', async () => {
  const app = createApp('${{ values.name }}');
  const server = app.listen(0);
  const { port } = server.address();
  const res = await fetch(`http://localhost:${port}/`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.status, 'ok');
  server.close();
});

test('GET /health returns healthy', async () => {
  const app = createApp('${{ values.name }}');
  const server = app.listen(0);
  const { port } = server.address();
  const res = await fetch(`http://localhost:${port}/health`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.status, 'healthy');
  server.close();
});
