const Announcement = require('../models/Announcement');

exports.postAnnouncement = async (req, res) => {
  try {
    const { title, broadcastTargets } = req.body;
    
    if (!req.file) return res.status(400).json({ error: "Audio file is required" });

    // Calculate Expiry: 24 hours from now
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const announcement = new Announcement({
      title,
      audioUrl: req.file.path, // Cloudinary URL
      userId: req.user.userId,
      broadcastTargets: broadcastTargets ? JSON.parse(broadcastTargets) : [],
      expiresAt
    });

    await announcement.save();
    res.status(201).json({ message: "Announcement posted", announcement });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getAnnouncements = async (req, res) => {
  try {
    const currentUserId = req.user.userId;

    // Filter Logic:
    // 1. Must not be expired (MongoDB handles deletion, but we check just in case)
    // 2. Either broadcastTargets is empty (Global) OR current user is in the list
    const announcements = await Announcement.find({
      $or: [
        { broadcastTargets: { $size: 0 } }, 
        { broadcastTargets: currentUserId },
        { userId: currentUserId } // Always show my own
      ]
    }).populate('userId', 'username profilePicture');

    res.status(200).json(announcements);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};