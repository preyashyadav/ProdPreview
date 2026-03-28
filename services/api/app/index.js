const express = require('express');

function createApp() {
  const app = express();

  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      service: 'api',
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/api/hello', (req, res) => {
    res.json({ message: 'Hello from the API!' });
  });

  return app;
}

const app = createApp();

if (require.main === module) {
  const port = Number(process.env.PORT || 4000);
  app.listen(port, () => {
    console.log(`API listening on port ${port}`);
  });
}

module.exports = app;
