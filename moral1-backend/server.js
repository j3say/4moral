require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authController = require('./controllers/authController');
const { protect } = require('./middleware/checkAuth');
const globalErrorHandler = require('./middleware/errorHandler');

const app = express();

// --- 1. Global Middleware ---
app.use(helmet()); // Security headers
app.use(cors()); // Allow cross-origin requests (for Flutter)
app.use(morgan('dev')); // Logging
app.use(express.json()); // Body parser

// --- 2. Routes ---
app.post('/api/auth/register', authController.register);
app.post('/api/auth/login', authController.login);

// Example Protected Route
app.get('/api/users/profile', protect, (req, res) => {
    res.status(200).json({
        status: 'success',
        data: { user: req.user }
    });
});

// --- 3. Error Handling ---
app.use(globalErrorHandler);

// --- 4. Database & Server Start ---
const PORT = process.env.PORT || 3000;
const DB_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/fourmoral_db';

mongoose.connect(DB_URI)
    .then(() => {
        console.log('✅ MongoDB Connected Successfully');
        app.listen(PORT, () => {
            console.log(`🚀 Server running on port ${PORT}`);
        });
    })
    .catch(err => {
        console.error('❌ DB Connection Error:', err);
    });