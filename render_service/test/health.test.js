const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const app = require('../server');

test('Health check endpoint returns 200 and valid JSON diagnostics', async (t) => {
  const server = app.listen(0); // Bind to random ephemeral port for testing
  const port = server.address().port;

  await new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/health`, (res) => {
      assert.strictEqual(res.statusCode, 200);

      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        const body = JSON.parse(data);
        assert.strictEqual(body.status, 'healthy');
        assert.strictEqual(body.checks.server, 'UP');
        assert.ok(typeof body.uptimeSeconds === 'number');
        assert.ok(typeof body.memoryUsageMB.rss === 'number');
        server.close(resolve);
      });
    }).on('error', (err) => {
      server.close();
      reject(err);
    });
  });
});
