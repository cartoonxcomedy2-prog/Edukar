const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: process.env.SMTP_PORT || 587,
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
    }
});

const sendEmail = async (to, subject, htmlContent) => {
    try {
        if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
            console.log('----------------------------------------------------');
            console.log(`[EMAIL MOCK] To: ${to}`);
            console.log(`[EMAIL MOCK] Subject: ${subject}`);
            console.log('Email not sent because SMTP credentials are not configured in .env');
            console.log('----------------------------------------------------');
            return true; // We don't want to crash the app if emails aren't configured
        }

        const info = await transporter.sendMail({
            from: `"EduKar Admissions" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
            to,
            subject,
            html: htmlContent
        });
        console.log('Email sent: %s', info.messageId);
        return true;
    } catch (error) {
        console.error('Error sending email:', error);
        return false;
    }
};

const getBaseTemplate = (title, content) => `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>${title}</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; margin: 0; padding: 0; color: #1e293b; -webkit-font-smoothing: antialiased; }
        .container { max-width: 650px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.05); border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 35px 30px; text-align: center; border-bottom: 4px solid #10B981; }
        .logo-text { color: #ffffff; font-size: 36px; font-weight: 900; margin: 0; display: inline-flex; align-items: center; gap: 12px; letter-spacing: -0.5px; }
        .content { padding: 45px 40px; }
        .footer { background: #f1f5f9; padding: 30px; text-align: center; color: #64748b; font-size: 13px; line-height: 1.6; border-top: 1px solid #e2e8f0; }
        .btn { display: inline-block; padding: 14px 32px; background-color: #10B981; color: #ffffff; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; margin-top: 25px; transition: background-color 0.3s; text-align: center; }
        .card { border: 1px solid #e2e8f0; border-radius: 12px; padding: 25px; margin: 30px 0; background: #f8fafc; display: flex; align-items: center; gap: 20px; }
        .card-img { width: 75px; height: 75px; border-radius: 10px; object-fit: cover; background: #cbd5e1; display: block; flex-shrink: 0; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .card-details { flex: 1; min-width: 0; }
        .card-details h3 { margin: 0 0 8px 0; font-size: 20px; color: #0f172a; font-weight: 800; line-height: 1.3; }
        .card-details p { margin: 0; color: #64748b; font-size: 14px; display: flex; align-items: center; gap: 6px; }
        .status-badge { display: inline-block; padding: 6px 14px; border-radius: 6px; font-size: 12px; font-weight: 800; text-transform: uppercase; margin-top: 12px; letter-spacing: 0.5px; }
        .status-applied { background: #e0f2fe; color: #0284c7; border: 1px solid #bae6fd; }
        .status-selected { background: #d1fae5; color: #059669; border: 1px solid #a7f3d0; }
        .status-rejected { background: #fee2e2; color: #dc2626; border: 1px solid #fecaca; }
        .status-test { background: #fef3c7; color: #d97706; border: 1px solid #fde68a; }
        .divider { height: 1px; background: #e2e8f0; margin: 30px 0; }
        .paragraph { font-size: 16px; line-height: 1.7; color: #475569; margin-bottom: 20px; }
        .highlight-box { background: #f8fafc; border: 1px solid #e2e8f0; border-left: 4px solid #10B981; padding: 20px; border-radius: 8px; margin: 25px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="logo-text">
                <span style="font-size: 40px; text-shadow: 0 2px 10px rgba(16, 185, 129, 0.3);">🎓</span> EduKar
            </h1>
        </div>
        <div class="content">
            ${content}
        </div>
        <div class="footer">
            <strong>EduKar Platform</strong><br>
            Empowering students to achieve academic excellence.<br>
            &copy; ${new Date().getFullYear()} EduKar. All rights reserved.<br>
            <span style="display:inline-block; margin-top:10px; font-size:11px; color:#94a3b8;">This is an automated message. Please do not reply directly to this email.</span>
        </div>
    </div>
</body>
</html>
`;

// Build absolute image URL for email
const getAbsoluteImageUrl = (thumbnailPath) => {
    if (!thumbnailPath) return '';
    if (thumbnailPath.startsWith('http')) return thumbnailPath;
    
    const baseUrl = process.env.BASE_URL || 'http://localhost:5000';
    const cleanPath = thumbnailPath.startsWith('/') ? thumbnailPath : '/' + thumbnailPath;
    return baseUrl + cleanPath;
};

const getStatusBadgeClass = (status) => {
    const s = (status || '').toLowerCase();
    if (s.includes('selected') || s.includes('approved')) return 'status-selected';
    if (s.includes('rejected')) return 'status-rejected';
    if (s.includes('test') || s.includes('interview') || s.includes('admit')) return 'status-test';
    return 'status-applied';
};

const getWelcomeEmailHTML = (userName) => {
    const firstName = userName ? userName.split(' ')[0] : 'Student';
    const content = `
        <h2 style="color: #0f172a; margin-top: 0; font-size: 26px; font-weight: 800;">Welcome to EduKar, ${firstName}! 🎉</h2>
        
        <p class="paragraph">
            Congratulations on successfully creating your account and taking a significant step toward advancing your academic journey! We are absolutely thrilled to welcome you to the <strong>EduKar Platform</strong>, your ultimate gateway to premier educational opportunities.
        </p>
        
        <div class="highlight-box">
            <h4 style="margin: 0 0 10px 0; color: #0f172a; font-size: 16px;">What can you do next?</h4>
            <ul style="margin: 0; padding-left: 20px; color: #475569; line-height: 1.6; font-size: 15px;">
                <li><strong>Explore Universities:</strong> Browse through a comprehensive directory of top-tier universities, complete with detailed program structures and fee breakdowns.</li>
                <li><strong>Find Scholarships:</strong> Discover fully-funded and partial scholarship opportunities tailored to help you fund your education.</li>
                <li><strong>Manage Documents:</strong> Securely upload and store your academic transcripts and certificates in a centralized, easily accessible digital vault.</li>
                <li><strong>Track Applications:</strong> Experience complete transparency with real-time status updates on all your submitted applications.</li>
            </ul>
        </div>

        <p class="paragraph">
            Our mission is to simplify the often complex admissions process, providing you with a seamless, stress-free experience from the moment you explore a program to the day you receive your offer letter.
        </p>

        <p class="paragraph">
            Whenever you are ready to begin, simply log into your dashboard and complete your personal profile. Ensuring your academic records are up-to-date will drastically improve your eligibility matches for exclusive opportunities.
        </p>

        
        
        <p class="paragraph" style="font-size: 15px;">
            We wish you the very best in your academic endeavors. If you ever need assistance, our support team is just a click away within the portal.
        </p>
        
        <p style="margin: 0; color: #0f172a; font-weight: bold; font-size: 16px;">
            Warm regards,<br>
            <span style="color: #10B981;">The EduKar Admissions Team</span>
        </p>
    `;
    return getBaseTemplate('Welcome to EduKar - Your Educational Journey Begins!', content);
};

const getApplicationSubmittedHTML = (userName, type, entityName, location, thumbnail) => {
    const firstName = userName ? userName.split(' ')[0] : 'Student';
    const absImage = getAbsoluteImageUrl(thumbnail);
    const imgHtml = absImage ? `<img src="${absImage}" alt="Thumbnail" class="card-img" onerror="this.style.display='none'">` : '<div style="width:75px;height:75px;background:#e2e8f0;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:32px;">🎓</div>';
    
    const content = `
        <h2 style="color: #0f172a; margin-top: 0; font-size: 26px; font-weight: 800;">Application Successfully Submitted! ✅</h2>
        
        <p class="paragraph">
            Dear ${firstName},
        </p>
        
        <p class="paragraph">
            We are writing to formally confirm that your application for the following ${type.toLowerCase()} has been successfully securely transmitted and received by our admissions processing center. 
        </p>
        
        <div class="card">
            ${imgHtml}
            <div class="card-details">
                <span style="font-size: 11px; font-weight: 900; color: #10B981; text-transform: uppercase; letter-spacing: 1px;">${type} Application</span>
                <h3>${entityName}</h3>
                <p>📍 ${location || 'Location details not specified'}</p>
                <div class="status-badge status-applied">Application Received</div>
            </div>
        </div>

        <h3 style="color: #0f172a; font-size: 18px; margin-top: 30px;">What happens next?</h3>
        <p class="paragraph">
            Your comprehensive profile and associated academic documents are currently undergoing preliminary verification by the respective admissions committee. 
            This standard review process ensures that all prerequisites and eligibility criteria align perfectly with the program's requirements.
        </p>

        <p class="paragraph">
            You do not need to take any further action at this moment. We prioritize transparency, which means any progression in your application—whether it leads to a scheduled interview, a merit-based test, or an official admission decision—will be instantly updated on your dashboard. Furthermore, you will receive automated email alerts matching those updates.
        </p>

        <p class="paragraph" style="font-size: 15px;">
            We appreciate your patience during this evaluation period and commend your commitment to furthering your education.
        </p>
        
        <div class="divider"></div>
        
        <p style="margin: 0; color: #0f172a; font-weight: bold; font-size: 16px;">
            Best of luck,<br>
            <span style="color: #10B981;">The EduKar Admissions Committee</span>
        </p>
    `;
    return getBaseTemplate('Application Successfully Received - EduKar', content);
};

const getStatusUpdateHTML = (userName, type, entityName, location, thumbnail, newStatus, testDate) => {
    const firstName = userName ? userName.split(' ')[0] : 'Student';
    const absImage = getAbsoluteImageUrl(thumbnail);
    const imgHtml = absImage ? `<img src="${absImage}" alt="Thumbnail" class="card-img" onerror="this.style.display='none'">` : '<div style="width:75px;height:75px;background:#e2e8f0;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:32px;">🎓</div>';
    const badgeClass = getStatusBadgeClass(newStatus);
    
    let extraInfoHtml = '';
    const sLow = newStatus.toLowerCase();
    
    // Test Date / Interview Info
    if (testDate && (sLow.includes('test') || sLow.includes('interview'))) {
        const dateObj = new Date(testDate);
        const formattedDate = dateObj.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
        const formattedTime = dateObj.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
        
        extraInfoHtml += `
            <div style="background: #fffbeb; border: 1px solid #fef3c7; border-left: 4px solid #f59e0b; padding: 25px; border-radius: 10px; margin: 30px 0;">
                <h4 style="margin: 0 0 10px 0; color: #b45309; font-size: 18px; display: flex; align-items: center; gap: 8px;">
                    <span style="font-size: 20px;">📅</span> Important Scheduling Notice
                </h4>
                <p style="margin: 0 0 10px 0; color: #92400e; font-size: 15px; line-height: 1.6;">
                    Please be advised that your mandatory evaluation has been officially scheduled. It is highly recommended to prepare your academic fundamentals accordingly.
                </p>
                <div style="background: rgba(255,255,255,0.6); padding: 15px; border-radius: 6px; margin-top: 15px;">
                    <strong style="color: #78350f; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Date & Time:</strong><br>
                    <span style="color: #b45309; font-size: 18px; font-weight: bold;">${formattedDate} at ${formattedTime}</span>
                </div>
            </div>
        `;
    }
    
    // Admit Card / Offer Letter generic message (without direct link, asking them to login)
    if (sLow.includes('admit card') || sLow.includes('offer letter') || sLow.includes('selected') || sLow.includes('approved')) {
         extraInfoHtml += `
            <div style="background: #f0fdf4; border: 1px solid #dcfce3; border-left: 4px solid #10b981; padding: 25px; border-radius: 10px; margin: 30px 0;">
                <h4 style="margin: 0 0 10px 0; color: #065f46; font-size: 18px; display: flex; align-items: center; gap: 8px;">
                    <span style="font-size: 20px;">📄</span> Official Document Available
                </h4>
                <p style="margin: 0; color: #064e3b; font-size: 15px; line-height: 1.6;">
                    We are pleased to inform you that an official document concerning your application has been securely generated and attached to your profile. For security and privacy compliance, we do not attach sensitive documents via email.
                </p>
                <p style="margin: 15px 0 0 0; color: #064e3b; font-size: 15px; font-weight: bold;">
                    Please log into your EduKar portal and navigate to the "Track Applications" section to securely view and download your document.
                </p>
            </div>
        `;
    }

    const content = `
        <h2 style="color: #0f172a; margin-top: 0; font-size: 26px; font-weight: 800;">Application Status Update 📢</h2>
        
        <p class="paragraph">
            Dear ${firstName},
        </p>

        <p class="paragraph">
            This is an automated notification to inform you that there has been a critical update concerning your recent application. The admissions board has registered a change in your evaluation status for the program detailed below.
        </p>
        
        <div class="card">
            ${imgHtml}
            <div class="card-details">
                <span style="font-size: 11px; font-weight: 900; color: #10B981; text-transform: uppercase; letter-spacing: 1px;">${type} Application</span>
                <h3>${entityName}</h3>
                <p>📍 ${location || 'Location details not specified'}</p>
                <div class="status-badge ${badgeClass}">${newStatus}</div>
            </div>
        </div>

        ${extraInfoHtml}

        <p class="paragraph">
            To view comprehensive details regarding this update and any potential remarks left by the evaluating committee, we request you to access your centralized tracking dashboard.
        </p>

        
        
        <div class="divider"></div>
        
        <p style="margin: 0; color: #0f172a; font-weight: bold; font-size: 16px;">
            Sincerely,<br>
            <span style="color: #10B981;">The EduKar Administrative Board</span>
        </p>
    `;
    return getBaseTemplate(`Official Status Update: ${entityName} - EduKar`, content);
};

module.exports = {
    sendEmail,
    getWelcomeEmailHTML,
    getApplicationSubmittedHTML,
    getStatusUpdateHTML
};
