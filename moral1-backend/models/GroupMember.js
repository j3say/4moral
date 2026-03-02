const mongoose = require('mongoose');

const groupMemberSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  role: { type: String, enum: ['admin', 'normal'], default: 'normal' },
  joinedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('GroupMember', groupMemberSchema);
