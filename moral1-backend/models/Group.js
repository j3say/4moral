const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, default: '' },
  groupPicUrl: { type: String, default: '' },
  createdBy: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'GroupMember' }],
  memberIds: [{ type: String }],
  isPublic: { type: Boolean, default: true },
  adminUid: { type: String, required: true },
  adminOnlyChat: { type: Boolean, default: false }
}, { timestamps: true });

module.exports = mongoose.model('Group', groupSchema);
