const User = require('../models/User');

exports.checkUsername = async (req, res, next) => {
  try {
    const { username } = req.query;
    const user = await User.findOne({ username });
    res.status(200).json({ available: !user });
  } catch (err) { next(err); }
};

exports.updateProfile = async (req, res, next) => {
  try {
    // req.file contains the uploaded image (via multer)
    // req.body contains text fields
    const updates = { ...req.body };
    
    // If image uploaded, save path (In prod, upload to S3 here and save URL)
    if (req.file) {
      updates.profilePicture = req.file.path; // Or S3 URL
    }

    updates.profileCompleted = true; // Critical flag update

    const updatedUser = await User.findByIdAndUpdate(req.user.id, updates, {
      new: true,
      runValidators: true
    });

    res.status(200).json({ status: 'success', user: updatedUser });
  } catch (err) { next(err); }
};