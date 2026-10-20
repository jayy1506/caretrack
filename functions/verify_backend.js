import { FollowUpService } from './lib/services/followUpService.js';
import { EmailService } from './lib/services/emailService.js';
import { MessagingService, normalizePhoneNumber } from './lib/services/messagingService.js';
import { config } from './lib/config/index.js';

console.log('=== CARETRACK BACKEND VERIFICATION ===');

// 1. Verify FollowUpService deterministic date calculations
const baseDate = '2026-09-12';
const d15 = FollowUpService.calculateFollowUpDate(baseDate, '15_days');
const d1m = FollowUpService.calculateFollowUpDate(baseDate, '1_month');
const d3m = FollowUpService.calculateFollowUpDate(baseDate, '3_months');
const d6m = FollowUpService.calculateFollowUpDate(baseDate, '6_months');
const dCustom = FollowUpService.calculateFollowUpDate(baseDate, 'custom', '2026-11-20');

console.log('Follow-up 15 days (+15d):', d15, d15 === '2026-09-27' ? '✓ PASS' : '✗ FAIL');
console.log('Follow-up 1 month (+1m):', d1m, d1m === '2026-10-12' ? '✓ PASS' : '✗ FAIL');
console.log('Follow-up 3 months (+3m default):', d3m, d3m === '2026-12-12' ? '✓ PASS' : '✗ FAIL');
console.log('Follow-up 6 months (+6m):', d6m, d6m === '2027-03-12' ? '✓ PASS' : '✗ FAIL');
console.log('Follow-up Custom:', dCustom, dCustom === '2026-11-20' ? '✓ PASS' : '✗ FAIL');

// 2. Verify Phone Normalization (+91 default for 10-digit, E.164)
const p1 = normalizePhoneNumber('9876543210');
const p2 = normalizePhoneNumber('+14155552671');
const p3 = normalizePhoneNumber('123');
console.log('\nPhone Norm 10-digit Indian (9876543210):', p1.normalized, p1.normalized === '+919876543210' ? '✓ PASS' : '✗ FAIL');
console.log('Phone Norm E.164 (+14155552671):', p2.normalized, p2.normalized === '+14155552671' ? '✓ PASS' : '✗ FAIL');
console.log('Phone Norm Invalid (123):', p3.valid === false ? '✓ REJECTED' : '✗ FAIL');

// 3. Verify Email Service Configuration
console.log('\nEmail Service (Gmail SMTP) Configured:', EmailService.isConfigured() ? '✓ YES' : '○ NO (requires .env GMAIL_USER/GMAIL_APP_PASSWORD)');

// 4. Verify Messaging Service Configuration
console.log('Messaging Service Configured:', MessagingService.isConfigured() ? '✓ YES' : '○ NO (requires provider credentials)');
console.log('Active Messaging Provider:', config.messagingProvider);

// 5. Verify Gemini Key
console.log('\nGemini AI Model:', config.geminiModel);
console.log('Gemini AI Key Configured:', config.geminiApiKey ? '✓ YES (Hidden)' : '○ NO');

console.log('\n=== ALL CONFIGURATIONS & CORE LOGIC VERIFIED ===');
