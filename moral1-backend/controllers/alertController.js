const AudioAlert = require('../models/AudioAlert');
const Notification = require('../models/Notification'); 
const User = require('../models/User');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

exports.createAlert = async (req, res) => {
    try {
        const userId = req.user._id; 
        const { title, type, scheduledFor } = req.body;

        if (!req.file) {
            return res.status(400).json({ error: "Audio file is required" });
        }

        const audioUrl = req.file.path;

        const startTime = scheduledFor ? new Date(scheduledFor) : new Date();
        const expiresAt = new Date(startTime.getTime() + 24 * 60 * 60 * 1000);

        const newAlert = new AudioAlert({
            holyPlaceId: userId,
            title,
            audioUrl,
            type, 
            scheduledFor: scheduledFor || null,
            expiresAt
        });

        await newAlert.save();

        const holyPlace = await User.findById(userId);
        const followers = holyPlace?.followers || [];
        if (type === 'prayer' && followers.length > 0) {
            const notifications = followers.map(followerId => ({
                recipient: followerId,
                sender: userId,
                type: 'prayer_alert',
                message: `New Prayer Alert from ${holyPlace.name || 'Holy Place'}: ${title}`,
                relatedId: newAlert._id
            }));
            await Notification.insertMany(notifications);
        }

        res.status(201).json({
            status: "success",
            message: `${type} created successfully.`,
            data: newAlert
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.getActiveAlerts = async (req, res) => {
    try {
        const { type } = req.query;
        const currentTime = new Date();
        const alerts = await AudioAlert.find({
            type: type,
            expiresAt: { $gt: currentTime }, 
            $or: [
                { scheduledFor: { $lte: currentTime } }, 
                { scheduledFor: null } 
            ]
        }).populate('userId', 'username profilePicture accountType');

        res.status(200).json({
            status: 'success',
            count: alerts.length,
            alerts
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

exports.getUserNotifications = async (req, res) => {
    try {
        const userId = req.user._id;
        const notifications = await Notification.find({ recipient: userId })
            .sort({ createdAt: -1 }) 
            .limit(20);

        res.status(200).json({
            status: 'success',
            count: notifications.length,
            notifications
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};