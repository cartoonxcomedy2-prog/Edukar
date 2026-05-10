const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');

const resetHameedPassword = async () => {
    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected!');

        const email = 'hameed@gmail.com';
        const user = await User.findOne({ email });

        if (!user) {
            console.log('❌ User hameed@gmail.com not found in the database.');
            process.exit(1);
        }

        // Set password to be the same as email
        user.password = email;
        await user.save();

        console.log('✅ Password for hameed@gmail.com has been updated to "hameed@gmail.com"');
        
        await mongoose.connection.close();
        process.exit(0);
    } catch (err) {
        console.error('Error:', err.message);
        process.exit(1);
    }
};

resetHameedPassword();
