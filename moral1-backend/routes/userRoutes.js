// routes/userRoutes.js
const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/uploadMiddleware');

router.get('/check-username', userController.checkUsername);
router.put('/profile', protect, upload.single('profileImage'), userController.updateProfile);
module.exports = router;