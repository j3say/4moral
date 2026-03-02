const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  username: { type: String },
  profilePicture: { type: String },
  mobileNumber: { type: String },
  dateTime: { type: String },
  comment: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('Comment', commentSchema);
