// routes/announcementRoutes.js
const express = require('express');
const router = express.Router();
const announcementController = require('../controllers/announcementController');
const { protect } = require('../middleware/authMiddleware');
const { upload } = require('../utils/storageWrapper'); 

// POST /api/announcements
// Note: using 'protect' now
router.post('/', protect, upload.single('audio'), announcementController.postAnnouncement);

// GET /api/announcements
router.get('/', protect, announcementController.getAnnouncements);

module.exports = router;