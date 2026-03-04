const multer = require('multer');
// Simple disk storage for Phase 1. Swap for S3 later.
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, `user-${Date.now()}-${file.originalname}`)
});
module.exports = multer({ storage });