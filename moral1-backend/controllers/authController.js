const User = require('../models/User');
const jwt = require('jsonwebtoken');

// Helper to generate JWT
const signToken = (id, accountType) => {
    return jwt.sign({ id, accountType }, process.env.JWT_SECRET, {
        expiresIn: '3d'
    });
};

// 1. Register User
exports.register = async (req, res, next) => {
    try {
        const { mobileNumber, password, name, accountType } = req.body;

        // Check for existing user
        const existingUser = await User.findOne({ mobileNumber });
        if (existingUser) {
            return res.status(400).json({ status: 'fail', message: 'Mobile number already in use' });
        }

        // Generate Custom Unique ID (e.g., MORAL_1709...)
        const uniqueId = `MORAL_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

        const newUser = await User.create({
            mobileNumber,
            password, // Will be hashed by pre('save')
            uniqueId,
            name,
            accountType: accountType || 'Standard'
        });

        // Generate Token
        const token = signToken(newUser._id, newUser.accountType);

        // Remove password from output
        newUser.password = undefined;

        res.status(201).json({
            status: 'success',
            token,
            data: { user: newUser }
        });

    } catch (error) {
        next(error); // Pass to global error handler
    }
};

// 2. Login User
exports.login = async (req, res, next) => {
    try {
        const { mobileNumber, password } = req.body;

        // 1. Check if email and password exist
        if (!mobileNumber || !password) {
            return res.status(400).json({ status: 'fail', message: 'Please provide mobile number and password' });
        }

        // 2. Check if user exists && password is correct
        // We must explicitly select '+password' because we set select: false in schema
        const user = await User.findOne({ mobileNumber }).select('+password');

        if (!user || !(await user.comparePassword(password))) {
            return res.status(401).json({ status: 'fail', message: 'Incorrect mobile number or password' });
        }

        // 3. If everything ok, send token
        const token = signToken(user._id, user.accountType);
        
        user.password = undefined; // Remove password from response

        res.status(200).json({
            status: 'success',
            token,
            data: { user }
        });

    } catch (error) {
        next(error);
    }
};