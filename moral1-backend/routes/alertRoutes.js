const express = require('express');
const router = express.Router();
const alertController = require('../controllers/alertController');
const { protect, restrictTo } = require('../middleware/authMiddleware');
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;

const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'moral1_prayers',
        resource_type: 'auto',
        allowed_formats: ['mp3', 'wav', 'm4a']
    },
});

const upload = multer({ storage: storage });

router.post('/create-prayer', protect, restrictTo('HolyPlace'), upload.single('audio'), alertController.createAlert);
router.get('/', protect, alertController.getActiveAlerts);
router.get('/notifications', protect, alertController.getUserNotifications);

module.exports = router;