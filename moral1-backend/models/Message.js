const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  senderId: { type: String, required: true },
  content: { type: String, required: true },
  type: { type: String, enum: ['text', 'image', 'video', 'audio', 'file'], default: 'text' },
  sentAt: { type: Date, default: Date.now },
  mediaUrl: { type: String },
  fileInfo: { type: String },
  isDeleted: { type: Boolean, default: false },
  deletedForEveryone: { type: Boolean, default: false },
  repliedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' }
}, { timestamps: true });

module.exports = mongoose.model('Message', messageSchema);
