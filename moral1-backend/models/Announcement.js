const mongoose = require('mongoose');

const announcementSchema = new mongoose.Schema({
  title: { type: String, required: true },
  audioUrl: { type: String, required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  
  // Selective Broadcast targets (List of User IDs)
  broadcastTargets: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], 
  
  createdAt: { type: Date, default: Date.now },
  
  // The TTL Index Field
  expiresAt: { 
    type: Date, 
    required: true,
    index: { expires: 0 } // Deletes the doc exactly when this time is reached
  }
}, { timestamps: true });

module.exports = mongoose.model('Announcement', announcementSchema);