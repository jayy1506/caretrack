export interface MetaWhatsAppTemplate {
  name: string;
  category: 'UTILITY' | 'MARKETING';
  language: 'en' | 'hi' | 'mr';
  header?: string;
  body: string;
  variables: string[]; // List of parameter explanations, e.g. ["Doctor Name", "Date", "Time"]
  status: 'APPROVED' | 'PENDING_SUBMISSION' | 'REJECTED';
}

/**
 * Canonical Registry of Meta WhatsApp Cloud API Templates for CareTrack
 * Documented for direct submission to Meta WhatsApp Business Manager.
 */
export const TEMPLATE_REGISTRY: Record<string, MetaWhatsAppTemplate[]> = {
  appointment_reminder: [
    {
      name: 'appointment_reminder',
      category: 'UTILITY',
      language: 'en',
      body: 'Reminder: Your appointment with Dr. {{1}} is scheduled for tomorrow ({{2}}) at {{3}}. Reply 1 to Confirm or 2 to Reschedule.',
      variables: ['Doctor Name', 'Date', 'Time'],
      status: 'APPROVED',
    },
    {
      name: 'appointment_reminder',
      category: 'UTILITY',
      language: 'hi',
      body: 'स्मरण पत्र: डॉ. {{1}} के साथ आपकी अपॉइंटमेंट कल ({{2}}) {{3}} बजे निर्धारित है। पुष्टि करने के लिए 1 या बदलने के लिए 2 भेजें।',
      variables: ['Doctor Name', 'Date', 'Time'],
      status: 'APPROVED',
    },
    {
      name: 'appointment_reminder',
      category: 'UTILITY',
      language: 'mr',
      body: 'आठवण: डॉ. {{1}} यांच्यासोबत आपली अपॉइंटमेंट उद्या ({{2}}) रोजी {{3}} वाजता आहे. पुष्टी करण्यासाठी 1 किंवा वेळ बदलण्यासाठी 2 पाठवा.',
      variables: ['Doctor Name', 'Date', 'Time'],
      status: 'APPROVED',
    },
  ],
  appointment_confirmation: [
    {
      name: 'appointment_confirmation',
      category: 'UTILITY',
      language: 'en',
      body: 'Hello! Your appointment with Dr. {{1}} is requested for {{2}} at {{3}}. Please confirm your booking here: {{4}}',
      variables: ['Doctor Name', 'Date', 'Time', 'Verification Link'],
      status: 'APPROVED',
    },
    {
      name: 'appointment_confirmation',
      category: 'UTILITY',
      language: 'hi',
      body: 'नमस्ते! डॉ. {{1}} के साथ आपकी अपॉइंटमेंट {{2}} को {{3}} बजे के लिए अनुरोधित है। कृपया यहाँ पुष्टि करें: {{4}}',
      variables: ['Doctor Name', 'Date', 'Time', 'Verification Link'],
      status: 'APPROVED',
    },
    {
      name: 'appointment_confirmation',
      category: 'UTILITY',
      language: 'mr',
      body: 'नमस्कार! डॉ. {{1}} यांच्याकडे आपली अपॉइंटमेंट {{2}} रोजी {{3}} वाजता नियोजित आहे. कृपया पुष्टी करा: {{4}}',
      variables: ['Doctor Name', 'Date', 'Time', 'Verification Link'],
      status: 'APPROVED',
    },
  ],
  recall_routine_checkup: [
    {
      name: 'recall_routine_checkup',
      category: 'MARKETING',
      language: 'en',
      body: 'Hello {{1}}, it has been over 6 months since your last dental visit at {{2}}. Routine preventive cleanings preserve your oral health. Book your slot: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Booking Link'],
      status: 'APPROVED',
    },
    {
      name: 'recall_routine_checkup',
      category: 'MARKETING',
      language: 'hi',
      body: 'नमस्ते {{1}}, {{2}} में आपकी पिछली दंत जांच को 6 महीने से अधिक हो गए हैं। नियमित जांच आपके दांतों को स्वस्थ रखती है। यहाँ स्लॉट चुनें: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Booking Link'],
      status: 'APPROVED',
    },
    {
      name: 'recall_routine_checkup',
      category: 'MARKETING',
      language: 'mr',
      body: 'नमस्कार {{1}}, {{2}} येथे आपल्या शेवटच्या दंत तपासणीला 6 महिन्यांपेक्षा जास्त काळ लोटला आहे. आपले दात सुरक्षित ठेवण्यासाठी नियमित तपासणी आवश्यक आहे. वेळ बुक करा: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Booking Link'],
      status: 'APPROVED',
    },
  ],
  recall_at_risk_plan: [
    {
      name: 'recall_at_risk_plan',
      category: 'UTILITY',
      language: 'en',
      body: 'Dear {{1}}, we noticed your recent stage for {{2}} was missed. Continuing your treatment on time is crucial for clinical success. Please contact {{3}} to reschedule.',
      variables: ['Patient Name', 'Treatment Plan Name', 'Clinic Phone / Link'],
      status: 'APPROVED',
    },
    {
      name: 'recall_at_risk_plan',
      category: 'UTILITY',
      language: 'hi',
      body: 'नमस्ते {{1}}, {{2}} के लिए आपका पिछला उपचार सत्र छूट गया था। बेहतर परिणाम के लिए समय पर उपचार जारी रखना महत्वपूर्ण है। कृपया {{3}} पर संपर्क करें।',
      variables: ['Patient Name', 'Treatment Plan Name', 'Clinic Phone / Link'],
      status: 'APPROVED',
    },
    {
      name: 'recall_at_risk_plan',
      category: 'UTILITY',
      language: 'mr',
      body: 'नमस्कार {{1}}, {{2}} चा पुढील उपचार सत्र चुकले आहे. उपचारांच्या यशासाठी वेळेवर सत्र पूर्ण करणे आवश्यक आहे. कृपया {{3}} वर संपर्क करा.',
      variables: ['Patient Name', 'Treatment Plan Name', 'Clinic Phone / Link'],
      status: 'APPROVED',
    },
  ],
  post_treatment_care: [
    {
      name: 'post_treatment_care',
      category: 'UTILITY',
      language: 'en',
      body: 'Hello {{1}}, here are your post-care instructions following your {{2}}: {{3}}. Reply to this message if you have any questions.',
      variables: ['Patient Name', 'Procedure Name', 'Care Instructions'],
      status: 'APPROVED',
    },
    {
      name: 'post_treatment_care',
      category: 'UTILITY',
      language: 'hi',
      body: 'नमस्ते {{1}}, {{2}} के बाद आपकी देखभाल संबंधी निर्देश: {{3}}। यदि कोई समस्या हो तो इस संदेश का उत्तर दें।',
      variables: ['Patient Name', 'Procedure Name', 'Care Instructions'],
      status: 'APPROVED',
    },
    {
      name: 'post_treatment_care',
      category: 'UTILITY',
      language: 'mr',
      body: 'नमस्कार {{1}}, {{2}} नंतर आपल्या काळजीसाठी सूचना: {{3}}. काही प्रश्न असल्यास या मेसेजला उत्तर द्या.',
      variables: ['Patient Name', 'Procedure Name', 'Care Instructions'],
      status: 'APPROVED',
    },
  ],
  clinic_review_request: [
    {
      name: 'clinic_review_request',
      category: 'MARKETING',
      language: 'en',
      body: 'Hello {{1}}, thank you for visiting {{2}} today! If you had a good experience, please take a moment to share your feedback: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Google Review Link'],
      status: 'APPROVED',
    },
    {
      name: 'clinic_review_request',
      category: 'MARKETING',
      language: 'hi',
      body: 'नमस्ते {{1}}, {{2}} में आने के लिए धन्यवाद! यदि आपका अनुभव अच्छा रहा, तो कृपया यहाँ अपनी समीक्षा साझा करें: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Google Review Link'],
      status: 'APPROVED',
    },
    {
      name: 'clinic_review_request',
      category: 'MARKETING',
      language: 'mr',
      body: 'नमस्कार {{1}}, {{2}} ला भेट दिल्याबद्दल धन्यवाद! आपला अनुभव चांगला राहिला असल्यास कृपया येथे प्रतिक्रिया नोंदवा: {{3}}',
      variables: ['Patient Name', 'Clinic Name', 'Google Review Link'],
      status: 'APPROVED',
    },
  ],
  medication_reminder: [
    {
      name: 'medication_reminder',
      category: 'UTILITY',
      language: 'en',
      body: 'Hello {{1}}, it is time for your medication: {{2}} ({{3}}). Tap here after taking your dose: {{4}}',
      variables: ['Patient Name', 'Medicine & Dosage', 'Timing Instructions', 'Taken Link'],
      status: 'APPROVED',
    },
    {
      name: 'medication_reminder',
      category: 'UTILITY',
      language: 'hi',
      body: 'नमस्ते {{1}}, आपकी दवा का समय हो गया है: {{2}} ({{3}})। दवा लेने के बाद यहाँ पुष्टि करें: {{4}}',
      variables: ['Patient Name', 'Medicine & Dosage', 'Timing Instructions', 'Taken Link'],
      status: 'APPROVED',
    },
    {
      name: 'medication_reminder',
      category: 'UTILITY',
      language: 'mr',
      body: 'नमस्कार {{1}}, आपल्या औषधाची वेळ झाली आहे: {{2}} ({{3}}). औषध घेतल्यानंतर येथे नोंद करा: {{4}}',
      variables: ['Patient Name', 'Medicine & Dosage', 'Timing Instructions', 'Taken Link'],
      status: 'APPROVED',
    },
  ],
};

export class TemplateRegistryService {
  /**
   * Retrieves a template definition for a specific template name and language
   */
  public static getTemplate(name: string, lang: 'en' | 'hi' | 'mr' = 'en'): MetaWhatsAppTemplate | undefined {
    const list = TEMPLATE_REGISTRY[name];
    if (!list) return undefined;
    return list.find((t) => t.language === lang) || list.find((t) => t.language === 'en');
  }

  /**
   * Returns list of all registered Meta WhatsApp templates
   */
  public static getAllTemplates(): MetaWhatsAppTemplate[] {
    return Object.values(TEMPLATE_REGISTRY).flat();
  }
}
