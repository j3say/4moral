const mongoose = require('mongoose');

const storySchema = new mongoose.Schema({
  keyDatabase: { type: String, required: true, unique: true },
  key: { type: String },
  dateTime: { type: String },
  caption: { type: String },
  mobileNumber: { type: String },
  profilePicture: { type: String },
  thumbnail: { type: String },
  type: { type: String },
  actype: { type: String },
  url: { type: String },
  username: { type: String },
  category: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('Story', storySchema);
