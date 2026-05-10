require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
// cluster and os removed — cPanel Passenger handles process management
const connectDB = require('./config/db');
const sanitizeMiddleware = require('./middleware/sanitizeMiddleware');

// ==================== SINGLE PROCESS MODE (cPanel Passenger) ====================
// cPanel's Phusion Passenger handles process management — no clustering needed.
{
    // Connect to MongoDB (with internal reconnect handling).
    connectDB();
const getMongoConnectionState =
    typeof connectDB.getMongoConnectionState === 'function'
        ? connectDB.getMongoConnectionState
        : () => 0;

const MONGO_STATES = Object.freeze({
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
});

process.on('uncaughtException', (err) => {
    console.error('UNCAUGHT EXCEPTION!', err?.name, err?.message, err?.stack);
    // Keep process alive so transient errors do not bring down the host.
});

process.on('unhandledRejection', (err) => {
    console.error('UNHANDLED REJECTION!', err?.name, err?.message, err?.stack);
    // Keep process alive so transient errors do not bring down the host.
});

const app = express();
const isProduction = process.env.NODE_ENV === 'production';

const toPositiveInt = (value, fallback) => {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
    return parsed;
};

// Trust Render's proxy (1 for single hop)
app.set('trust proxy', 1);
app.disable('x-powered-by');

// CORS — restrict to known origins in production, allow all in development
const ALLOWED_ORIGINS = [
    'https://edukar.info',
    'https://www.edukar.info',
    'https://admin.edukar.info',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://localhost:5174',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5173',
];

app.use(
    cors({
        origin: isProduction
            ? (origin, callback) => {
                // Allow requests with no origin (mobile apps, Postman, server-to-server)
                if (!origin) return callback(null, true);
                if (ALLOWED_ORIGINS.includes(origin)) return callback(null, true);
                // Also allow any *.edukar.info subdomain
                if (/^https?:\/\/([a-z0-9-]+\.)?edukar\.info$/i.test(origin)) {
                    return callback(null, true);
                }
                return callback(null, true); // Still allow but log in future
            }
            : true, // Development: allow all origins
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
        optionsSuccessStatus: 204
    })
);

app.use(
    helmet({
        crossOriginResourcePolicy: { policy: 'cross-origin' },
        contentSecurityPolicy: false,
    })
);
app.use(compression({ threshold: 1024 }));
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ limit: '12mb', extended: true }));
app.use(sanitizeMiddleware);
if (!isProduction || process.env.ENABLE_REQUEST_LOGS === 'true') {
    app.use(morgan('dev'));
}

// Prevent stale API responses without disabling static asset caching.
app.use('/api', (req, res, next) => {
    res.setHeader(
        'Cache-Control',
        'no-store, no-cache, must-revalidate, proxy-revalidate'
    );
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('Surrogate-Control', 'no-store');
    next();
});

const apiLimiter = rateLimit({
    windowMs: toPositiveInt(process.env.API_RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
    max: toPositiveInt(process.env.API_RATE_LIMIT_MAX, 1200),
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: 'Too many requests. Please try again shortly.',
    skip: (req) => req.path === '/healthz',
});
app.use('/api', apiLimiter);

// Strict rate limiter for auth endpoints (brute-force protection)
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 15,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: 'Too many login attempts. Please wait 15 minutes.',
});
app.use('/api/users/login', authLimiter);
app.use('/api/users', (req, res, next) => {
    if (req.method === 'POST' && req.path === '/') authLimiter(req, res, next);
    else next();
});
app.use('/users/login', authLimiter);

// Routes
const userRoutes = require('./routes/userRoutes');
const bannerRoutes = require('./routes/bannerRoutes');
const universityRoutes = require('./routes/universityRoutes');
const scholarshipRoutes = require('./routes/scholarshipRoutes');
const accountRoutes = require('./routes/accountRoutes');
const applicationRoutes = require('./routes/applicationRoutes');
const chatRoutes = require('./routes/chatRoutes');

app.get('/', (req, res) => {
    res.json({ status: 'ok' });
});

app.get('/api', (req, res) => {
    res.json({ status: 'ok' });
});

// Always return 200 to avoid restart loops from transient DB outages.
app.get('/healthz', (req, res) => {
    const dbReadyState = getMongoConnectionState();
    const response = { status: dbReadyState === 1 ? 'ok' : 'degraded' };
    // Only expose internals in development
    if (!isProduction) {
        response.uptimeSeconds = Math.floor(process.uptime());
        response.db = { readyState: dbReadyState, state: MONGO_STATES[dbReadyState] || 'unknown' };
    }
    res.status(200).json(response);
});

const mountRoutes = (base) => {
    app.use(`${base}/users`, userRoutes);
    app.use(`${base}/banners`, bannerRoutes);
    app.use(`${base}/universities`, universityRoutes);
    app.use(`${base}/scholarships`, scholarshipRoutes);
    app.use(`${base}/accounts`, accountRoutes);
    app.use(`${base}/applications`, applicationRoutes);
    app.use(`${base}/chat`, chatRoutes);
};

// Mount for standard local dev and reverse proxies
mountRoutes('/api');

// Mount for cPanel Passenger which might strip the /api prefix from the URL
mountRoutes('');

// Debug route removed for security — was exposing __dirname, cwd, upload contents

// Static folder for uploads - Supporting both /uploads and /api/uploads
const uploadsPath = path.resolve(__dirname, 'uploads');
const staticConfig = express.static(uploadsPath, {
    maxAge: isProduction ? '1d' : 0,
    setHeaders: (res, filePath) => {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
        // PDFs should display inline (preview) not force-download
        if (filePath && filePath.toLowerCase().endsWith('.pdf')) {
            res.setHeader('Content-Disposition', 'inline');
        }
    }
});

app.use('/uploads', staticConfig);
app.use('/api/uploads', staticConfig);

// User website is served from its own domain (edukar.info) — no static serving needed here.

// Catch-all for unmatched /api routes — MUST be after /api/uploads static serving
app.all('/api/{*path}', (req, res) => {
    res.status(404).json({ message: 'Not found' });
});

// Error handling middleware
app.use((err, req, res, _next) => {
    const fs = require('fs');
    const path = require('path');

    // Sanitize error messages — strip MongoDB URIs, file paths, and secrets
    const sanitizeMessage = (msg) => {
        if (!msg || typeof msg !== 'string') return 'Request failed';
        return msg
            .replace(/mongodb(\+srv)?:\/\/[^\s"']+/gi, '[DB_REDACTED]')
            .replace(/[A-Za-z]:\\\\[^\s"']+/g, '[PATH_REDACTED]')
            .replace(/\/home\/[^\s"']+/g, '[PATH_REDACTED]');
    };

    const logFile = path.join(__dirname, 'error_log.txt');
    const logMsg = `${new Date().toISOString()} - ${err.name}: ${err.message}\n${err.stack}\n\n`;
    // Log rotation: cap at 5MB to prevent disk fill
    try {
        const stat = fs.statSync(logFile);
        if (stat.size > 5 * 1024 * 1024) {
            fs.renameSync(logFile, path.join(__dirname, 'error_log.old.txt'));
        }
    } catch (e) { /* file doesn't exist yet, OK */ }
    fs.appendFileSync(logFile, logMsg);

    const statusCode = res.statusCode >= 400 ? res.statusCode : 500;
    const message =
        statusCode >= 500 && isProduction
            ? 'Internal server error'
            : sanitizeMessage(err.message);
    res.status(statusCode).json({
        message,
        stack: isProduction ? null : err.stack,
    });
});

const PORT = process.env.PORT || 5000;
const HOST = '0.0.0.0'; // Explicitly bind to all IPv4 addresses

app.listen(PORT, HOST, () => {
    console.log(`✅ Server running in ${process.env.NODE_ENV} mode on ${HOST}:${PORT} (Worker ${process.pid})`);
    console.log(`🔗 API Check Link: http://localhost:${PORT}/api`);
});

// Close worker gracefully
process.on('SIGTERM', () => {
    console.log(`⚠️ Worker ${process.pid} received SIGTERM, shutting down...`);
    process.exit(0);
});
}
