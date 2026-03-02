const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  caption: { type: String, default: '' },
  dateTime: { type: String },
  mobileNumber: { type: String },
  profilePicture: { type: String, default: '' },
  thumbnail: [{ type: String }],
  type: { type: String },
  actype: { type: String },
  urls: [{ type: String }],
  mediaTypes: [{ type: String }],
  username: { type: String },
  numberOfLikes: { type: Number, default: 0 },
  likesUsers: { type: String, default: '' },
  postCategory: { type: String, default: '' },
  hasLocation: { type: Boolean, default: false },
  latitude: { type: Number },
  longitude: { type: Number }
}, { timestamps: true });

module.exports = mongoose.model('Post', postSchema);
