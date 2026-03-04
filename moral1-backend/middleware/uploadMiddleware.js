const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// 1. Configure Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

// 2. Set up Cloudinary Storage Engine
const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'fourmoral_users', // Folder name in your Cloudinary media library
        allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        // Optional: compress and resize the image on the fly
        transformation: [{ width: 500, height: 500, crop: 'limit' }] 
    }
});

// 3. Export Multer
module.exports = multer({ storage });