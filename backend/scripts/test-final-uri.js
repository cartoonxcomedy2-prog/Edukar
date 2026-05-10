const mongoose = require('mongoose');

const testConnection = async () => {
    const uri = 'mongodb+srv://univsindh:univsindh@cluster0.j6jzu2k.mongodb.net/sindh_db';
    console.log('Testing connection with password: univsindh');
    try {
        await mongoose.connect(uri, {
            serverSelectionTimeoutMS: 5000
        });
        console.log('✅ Success! The credentials "univsindh:univsindh" are working.');
        await mongoose.connection.close();
        process.exit(0);
    } catch (err) {
        console.error('❌ Connection failed:', err.message);
        process.exit(1);
    }
};

testConnection();
