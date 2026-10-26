const express = require('express');
const router = express.Router();

/**
 * Production Health Check Endpoint
 * Path: GET /health
 * 
 * Provides runtime diagnostics, uptime, memory footprints, and service states.
 * Suitable for Render zero-downtime deploy verification and scheduled monitoring.
 */
router.get('/health', async (req, res) => {
  const startTime = Date.now();

  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    environment: process.env.NODE_ENV || 'production',
    memoryUsageMB: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024),
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    },
    checks: {
      server: 'UP',
    },
  };

  try {
    // If you have a database connection (PostgreSQL, Supabase, Redis, Mongo),
    // perform a non-blocking check here (e.g., await db.query('SELECT 1')):
    // await db.query('SELECT 1');
    // healthData.checks.database = 'UP';

    healthData.responseTimeMs = Date.now() - startTime;
    return res.status(200).json(healthData);
  } catch (err) {
    healthData.status = 'degraded';
    healthData.checks.database = 'DOWN';
    healthData.error = process.env.NODE_ENV === 'production' 
      ? 'Database connectivity check failed' 
      : err.message;
    healthData.responseTimeMs = Date.now() - startTime;

    // Return 503 so Render & external monitors immediately recognize unhealthy status
    return res.status(503).json(healthData);
  }
});

module.exports = router;
