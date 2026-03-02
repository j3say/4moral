const express = require('express');
const router = express.Router();
const alertController = require('../controllers/alertController');
const multer = require('multer');

// Temporary Memory Storage for today (until we get AWS S3 keys tomorrow)
const upload = multer({ storage: multer.memoryStorage() });

// Mock Auth Middleware (To simulate a logged-in user)
// Next, we will write a proper JWT verify middleware!
const mockAuth = (req, res, next) => {
    req.user = { userId: "65f0a1b2c3d4e5f6g7h8i9j0" }; // Fake MongoDB ID for testing
    next();
};

// Routes
router.post('/create', mockAuth, upload.single('audio'), alertController.createAlert);
router.get('/', mockAuth, alertController.getActiveAlerts);

module.exports = router;