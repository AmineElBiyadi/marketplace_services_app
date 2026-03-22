const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");
const sgMail = require("@sendgrid/mail");

/**
 * Cloud Function to send emails securely from the server.
 * Supports both SMTP (Nodemailer) and SendGrid API.
 */
exports.sendEmail = onCall(async (request) => {
    const { to, subject, text, html, credentials } = request.data;

    if (!to || !subject || (!text && !html)) {
        throw new HttpsError("invalid-argument", "Missing recipient, subject, or message body.");
    }

    // --- Option 1: SendGrid API ---
    if (credentials.sendGridKey && credentials.sendGridKey !== "SG.votre_cle_ici") {
        logger.info("Sending email via SendGrid to: " + to);
        sgMail.setApiKey(credentials.sendGridKey);
        const msg = {
            to: to,
            from: {
                email: credentials.fromEmail,
                name: credentials.fromName || "Marketplace Admin",
            },
            subject: subject,
            text: text,
            html: html,
        };

        try {
            await sgMail.send(msg);
            return { success: true, method: "sendgrid" };
        } catch (error) {
            logger.error("SendGrid Error:", error);
            throw new HttpsError("internal", "SendGrid failed: " + error.message);
        }
    }

    // --- Option 2: SMTP (Nodemailer) ---
    if (credentials.smtpHost && credentials.smtpPass) {
        logger.info("Sending email via SMTP to: " + to);
        const transporter = nodemailer.createTransport({
            host: credentials.smtpHost,
            port: parseInt(credentials.smtpPort) || 465,
            secure: parseInt(credentials.smtpPort) === 465,
            auth: {
                user: credentials.fromEmail,
                pass: credentials.smtpPass,
            },
        });

        try {
            await transporter.sendMail({
                from: `"${credentials.fromName || "Marketplace Admin"}" <${credentials.fromEmail}>`,
                to: to,
                subject: subject,
                text: text,
                html: html,
            });
            return { success: true, method: "smtp" };
        } catch (error) {
            logger.error("SMTP Error:", error);
            throw new HttpsError("internal", "SMTP failed: " + error.message);
        }
    }

    throw new HttpsError("failed-precondition", "No valid email credentials provided.");
});
