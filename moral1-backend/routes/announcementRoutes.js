const express = require('express');
const router = express.Router();
const announcementController = require('../controllers/announcementController');
const { authenticate } = require('../middleware/auth'); 
// IMPORT THE CLOUDINARY WRAPPER HERE!
const { upload } = require('../utils/storageWrapper'); 

// POST /api/announcements (Fixed function name to postAnnouncement)
router.post('/', authenticate, upload.single('audio'), announcementController.postAnnouncement);

// GET /api/announcements
router.get('/', authenticate, announcementController.getAnnouncements);

module.exports = router;