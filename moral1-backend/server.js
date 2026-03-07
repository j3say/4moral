require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const metaRoutes = require('./routes/metaRoutes');
const globalErrorHandler = require('./middleware/errorHandler');
const announcementRoutes = require('./routes/announcementRoutes');

const app = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(cors({
  origin: 'http://localhost:53801', // Match your Flutter web port
  credentials: true
}));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/meta', metaRoutes);
app.use('/api/announcements', announcementRoutes);

// Global Error Handler
app.use(globalErrorHandler);

// DB & Server
const LOCAL_MONGO_URI = 'mongodb://localhost:27017/moral1';
const REMOTE_MONGO_URI = process.env.MONGO_URI;

async function connectWithFallback() {
  try {
    // Try remote (Atlas) first
    await mongoose.connect(REMOTE_MONGO_URI, { serverSelectionTimeoutMS: 1000 });
    console.log('✅ MongoDB Atlas Connected');
  } catch (err) {
    console.error('❌ Atlas DB Error:', err);
    try {
      // Fallback to local
      await mongoose.connect(LOCAL_MONGO_URI);
      console.log('✅ Local MongoDB Connected');
    } catch (localErr) {
      console.error('❌ Local DB Error:', localErr);
    }
  }
}

connectWithFallback();

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));