import express from 'express';
import promBundle from 'express-prom-bundle';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const app = express();

app.use(promBundle({ includeMethod: true, includePath: true }));

app.get('/health.json', (req, res) => {
  res.json({
    status: 'ok',
    service: 'frontend',
    timestamp: new Date().toISOString(),
  });
});

app.use(express.static(path.join(__dirname, 'dist')));
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist/index.html'));
});

export function startServer(port = Number(process.env.PORT || 3000)) {
  return app.listen(port, () => {
    console.log(`Frontend listening on port ${port}`);
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  startServer();
}
