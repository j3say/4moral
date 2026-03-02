const User = require('../models/User');
const jwt = require('jsonwebtoken');

// 1. Send OTP (Mock for now to avoid dependency on Client)
exports.sendOtp = async (req, res) => {
    try {
        const { mobileNumber } = req.body;
        if (!mobileNumber) return res.status(400).json({ error: "Mobile number is required" });

        // In production, integrate Twilio or MSG91 here.
        // For now, we mock it. The OTP is 123456.
        console.log(`Sending Mock OTP 123456 to ${mobileNumber}`);

        res.status(200).json({ message: "OTP sent successfully (Mock: 123456)" });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// 2. Verify OTP & Login/Signup
exports.verifyOtp = async (req, res) => {
    try {
        const { mobileNumber, otp } = req.body;

        // Verify our Mock OTP
        if (otp !== '123456') {
            return res.status(400).json({ error: "Invalid OTP" });
        }

        // Check if user exists
        let user = await User.findOne({ mobileNumber });
        let isNewUser = false;

        // If user doesn't exist, create a base standard account
        if (!user) {
            user = new User({
                mobileNumber,
                uniqueId: `MORAL1_${Date.now()}`, // Temporary unique ID
                accountType: 'Standard', // Default type
            });
            await user.save();
            isNewUser = true;
        }

        // Generate JWT Token
        const token = jwt.sign(
            { userId: user._id, accountType: user.accountType },
            process.env.JWT_SECRET,
            { expiresIn: '30d' } // Token valid for 30 days
        );

        res.status(200).json({
            message: "Login successful",
            token,
            isNewUser,
            user
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};