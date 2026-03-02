const AudioAlert = require('../models/AudioAlert');

// 1. Create Announcement or Prayer
exports.createAlert = async (req, res) => {
    try {
        // req.user will come from JWT middleware (auth)
        const userId = req.user.userId; 
        const { title, type, scheduledFor } = req.body;

        // Ensure file is attached
        if (!req.file) {
            return res.status(400).json({ error: "Audio file is required" });
        }

        // TODO: Tomorrow, replace this with the AWS S3 URL returned by multer-s3
        const audioUrl = `https://mock-s3-url.com/audio/${req.file.originalname}`;

        // Calculate 24-hour Expiry from now (or from scheduled time)
        const startTime = scheduledFor ? new Date(scheduledFor) : new Date();
        const expiresAt = new Date(startTime.getTime() + 24 * 60 * 60 * 1000); // +24 hours

        const newAlert = new AudioAlert({
            userId,
            title,
            audioUrl,
            type, // 'announcement' or 'prayer'
            scheduledFor: scheduledFor || null,
            expiresAt
        });

        await newAlert.save();

        res.status(201).json({
            message: `${type} created successfully. It will auto-delete in 24 hours.`,
            alert: newAlert
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// 2. Get Active Alerts
exports.getActiveAlerts = async (req, res) => {
    try {
        const { type } = req.query; // pass ?type=announcement or prayer
        
        // Fetch alerts that haven't expired yet
        const alerts = await AudioAlert.find({ 
            type: type,
            expiresAt: { $gt: new Date() } 
        }).populate('userId', 'username profilePicture accountType');

        res.status(200).json({ count: alerts.length, alerts });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};