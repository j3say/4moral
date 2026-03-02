const mongoose = require('mongoose');

const contactsSchema = new mongoose.Schema({
  name: { type: String },
  username: { type: String },
  profilePicture: { type: String },
  mobileNumber: { type: String },
  uniqueId: { type: String },
  isSelected: { type: Boolean, default: false }
});

module.exports = mongoose.model('Contacts', contactsSchema);
