const mongoose = require('mongoose');

const prayerSchema = new mongoose.Schema({
  title: { type: String, required: true },
  audioUrl: { type: String, required: true }, // Cloudinary link
  
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  subscribers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  
  createdAt: { type: Date, default: Date.now },
  
  expiresAt: { type: Date, required: true, index: { expires: '0' } } 
}, { timestamps: true });

module.exports = mongoose.model('Prayer', prayerSchema);