const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, default: 'prayer_alert' },
  message: { type: String, required: true },
  relatedId: { type: mongoose.Schema.Types.ObjectId, ref: 'AudioAlert' },
  status: { type: String, enum: ['unread', 'read'], default: 'unread' }
}, { timestamps: true });

module.exports = mongoose.model('Notification', notificationSchema);


// const notificationSchema = new mongoose.Schema({
//   key: { type: String, required: true, unique: true },
//   type: { type: String },
//   mobileNumber: { type: String },
//   comment: { type: String },
//   time: { type: String },
//   url: { type: String },
//   postId: { type: String },
//   profilePicture: { type: String },
//   username: { type: String },
//   message: { type: String },
//   status: { type: String }
// }, { timestamps: true });

