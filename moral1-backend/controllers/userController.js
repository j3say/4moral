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
        const updates = { ...req.body };
        
        // If an image was uploaded, save the live Cloudinary URL
        if (req.file) {
            updates.profilePicture = req.file.path; // This is now a secure https://res.cloudinary.com/... URL
        }

        updates.profileCompleted = true;

        const updatedUser = await User.findByIdAndUpdate(req.user.id, updates, {
            new: true,
            runValidators: true
        });

        res.status(200).json({ status: 'success', user: updatedUser });
    } catch (err) { 
        next(err); 
    }
};