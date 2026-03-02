const mongoose = require('mongoose');

const audioAlertSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, required: true }, // Permanent metadata
    audioUrl: { type: String, required: true }, // Cloudinary/S3 link
    
    // Distinguish between the two features
    type: { type: String, enum: ['announcement', 'prayer'], required: true },
    
    // Targeted Broadcast
    subscribers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    
    // Scheduling Logic
    scheduledFor: { type: Date, default: null }, // Null means send immediately
    
    // Auto-Delete Logic (TTL Index)
    expiresAt: { 
        type: Date, 
        required: true,
        index: { expires: '0' } // MongoDB will auto-delete the doc when this time hits
    }
}, { timestamps: true });

module.exports = mongoose.model('AudioAlert', audioAlertSchema);