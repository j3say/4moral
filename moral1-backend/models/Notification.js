const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  type: { type: String },
  mobileNumber: { type: String },
  comment: { type: String },
  time: { type: String },
  url: { type: String },
  postId: { type: String },
  profilePicture: { type: String },
  username: { type: String },
  message: { type: String },
  status: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('Notification', notificationSchema);
