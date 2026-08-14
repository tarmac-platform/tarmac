const express = require('express');

function createApp(name) {
  const app = express();
  app.use(express.json());

  app.get('/', (_req, res) => {
    res.json({ name, status: 'ok' });
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'healthy' });
  });

  return app;
}

if (require.main === module) {
  const port = process.env.PORT || 3000;
  createApp('${{ values.name }}').listen(port, () => {
    console.log(`${{ values.name }} listening on http://localhost:${port}`);
  });
}

module.exports = { createApp };
