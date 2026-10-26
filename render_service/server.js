const express = require('express');
const healthRouter = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

// Security & Parsing Middlewares
app.disable('x-powered-by');
app.use(express.json());

// Mount Health Check endpoint BEFORE rate limiting or authentication
app.use(healthRouter);

// Sample Base Route
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Render Express API',
    status: 'online',
    healthCheck: '/health',
  });
});

// Graceful 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Centralized error handler (prevents leaking internal stack traces in production)
app.use((err, req, res, next) => {
  console.error('[Application Error]:', err.message);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? 'An unexpected error occurred' : err.message,
  });
});

// Start HTTP Server only when invoked directly (not required as a test module)
let server;
if (require.main === module) {
  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Express] Service running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
  });
}

// Graceful Shutdown handling for Render deploy container termination
process.on('SIGTERM', () => {
  console.log('[Express] SIGTERM received. Closing HTTP server gracefully...');
  if (server) {
    server.close(() => {
      console.log('[Express] HTTP server terminated successfully.');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
});

module.exports = app;
