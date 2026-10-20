import { db, COLLECTIONS } from '../config/index.js';
import { ClinicFaqDocument, FaqQueryResult } from '../types/index.js';
import { AuditService } from './auditService.js';

export interface DefaultKnowledgeDoc {
  id: string;
  title: string;
  category: 'timings' | 'location' | 'services' | 'faq' | 'policy';
  content: string;
  keywords: string[];
}

export class FaqAssistantService {
  /**
   * Pre-seeded canonical dental clinic documents for grounded RAG.
   */
  public static readonly CANONICAL_DOCS: DefaultKnowledgeDoc[] = [
    {
      id: 'clinic_timings',
      title: 'Clinic Timings & Working Hours',
      category: 'timings',
      content:
        'CareTrack Dental Clinic operates Monday through Saturday from 09:00 AM to 08:00 PM. Sunday is reserved for pre-booked emergencies only. Doctor lunch hours are 01:30 PM to 02:30 PM.',
      keywords: ['timing', 'hours', 'open', 'close', 'sunday', 'lunch', 'working', 'schedule', 'time'],
    },
    {
      id: 'clinic_location',
      title: 'Clinic Address & Directions',
      category: 'location',
      content:
        'CareTrack Dental Clinic is located at Prime Medical Centre, 2nd Floor, Station Road. Dedicated two-wheeler and four-wheeler patient parking is available on premises. Landmark: Opposite Central Metro Station.',
      keywords: ['location', 'address', 'where', 'direction', 'landmark', 'metro', 'parking', 'map', 'reach'],
    },
    {
      id: 'services_cleaning',
      title: 'Dental Scaling & Teeth Cleaning',
      category: 'services',
      content:
        'Teeth Cleaning & Scaling gently removes plaque, calculus (tartar), and surface stains using ultrasonic technology. It prevents gingivitis and periodontitis. Dentists recommend professional scaling once every 6 months. The procedure takes approximately 30 to 45 minutes.',
      keywords: ['cleaning', 'scaling', 'tartar', 'plaque', 'stains', 'gums', 'teeth cleaning', 'polish'],
    },
    {
      id: 'services_rct',
      title: 'Root Canal Treatment (RCT)',
      category: 'services',
      content:
        'Root Canal Treatment (RCT) is a dental procedure to eliminate infection from the tooth pulp and preserve your natural tooth. Done under local anesthesia, modern RCT is virtually painless. It typically requires 2 to 3 sittings depending on case severity.',
      keywords: ['rct', 'root canal', 'nerve', 'sittings', 'crown', 'saving tooth', 'pulp'],
    },
    {
      id: 'services_braces',
      title: 'Orthodontics & Clear Aligners',
      category: 'services',
      content:
        'We offer conventional metal braces, ceramic aesthetic braces, and invisible clear aligners for teeth straightening and bite correction. Orthodontic review appointments occur once every 4 to 6 weeks.',
      keywords: ['braces', 'aligners', 'invisalign', 'straightening', 'crooked', 'wire', 'orthodontic'],
    },
    {
      id: 'services_extraction',
      title: 'Tooth Extraction & Wisdom Teeth',
      category: 'services',
      content:
        'Tooth extraction is performed when a tooth is non-restorable or deeply impacted (such as wisdom teeth). Modern extractions are performed under local anesthesia. Full postoperative care instructions are provided immediately following treatment.',
      keywords: ['extraction', 'remove tooth', 'wisdom tooth', 'pull tooth', 'removal'],
    },
    {
      id: 'reschedule_policy',
      title: 'Cancellation & Reschedule Policy',
      category: 'policy',
      content:
        'Appointments can be rescheduled or cancelled with at least 2 hours advance notice via the self-service web link or by replying "2" to our reminder message. Changes within 2 hours require direct coordination with our reception staff.',
      keywords: ['cancel', 'reschedule', 'change appointment', 'policy', 'cutoff', 'late', 'hours'],
    },
  ];

  /**
   * Clinical symptoms and emergency keywords across English, Hindi, and Marathi.
   */
  private static readonly CLINICAL_SYMPTOM_REGEX =
    /\b(pain|severe pain|bleeding|blood|fever|swelling|swollen|pus|trauma|broken tooth|infection|antibiotic|dosage|dose|medicine name|tablet|ache|throbbing|stitch|suture|hurt|emergency|दर्द|खून|सूजन|बुखार|टाके|तकलीफ़|मवाद|त्रास|सूज|रक्त|ताप|दुखणे|पू)\b/i;

  /**
   * Normalizes string for token search.
   */
  private static tokenize(text: string): string[] {
    return (text || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 2);
  }

  /**
   * Checks if an incoming query is asking for medical/clinical diagnosis, symptom relief, or emergency advice.
   */
  public static isClinicalOrEmergency(query: string): boolean {
    return this.CLINICAL_SYMPTOM_REGEX.test(query);
  }

  /**
   * Evaluates query against clinic documents and produces grounded answer or staff handoff.
   */
  public static async queryFaq(params: {
    clinicId: string;
    patientId: string;
    query: string;
    preferredLanguage?: 'en' | 'hi' | 'mr';
  }): Promise<FaqQueryResult> {
    const { clinicId, patientId, query, preferredLanguage = 'en' } = params;

    // 1. Strict Clinical & Emergency Guardrail
    if (this.isClinicalOrEmergency(query)) {
      await AuditService.log({
        clinicId,
        userId: patientId,
        action: 'FAQ_HANDOFF_CLINICAL',
        entityType: 'conversation',
        entityId: patientId,
        details: {
          querySnippet: query.substring(0, 50),
          reason: 'Clinical symptom or medication inquiry detected. Automated clinical advice strictly prohibited.',
        },
      });

      let handoffMessage =
        'I notice you are inquiring about clinical symptoms or discomfort. For your safety, automated medical advice is not provided. Our clinic doctor and team have been notified to review your query and contact you promptly.';
      if (preferredLanguage === 'hi') {
        handoffMessage =
          'हमने देखा कि आप स्वास्थ्य लक्षण या तकलीफ़ के बारे में पूछ रहे हैं। आपकी सुरक्षा के लिए ऑटोमेटेड मेडिकल सलाह नहीं दी जाती। हमारे डॉक्टर और टीम को सूचित कर दिया गया है, वे जल्द ही आपसे संपर्क करेंगे।';
      } else if (preferredLanguage === 'mr') {
        handoffMessage =
          'आपण लक्षणे किंवा त्रासाबद्दल विचारणा करत आहात. आपल्या सुरक्षिततेसाठी ऑटोमेटेड वैद्यकीय सल्ला दिला जात नाही. आमच्या डॉक्टरांना आणि टीमला कळवले आहे, ते लवकरच आपल्याशी संपर्क साधतील.';
      }

      return {
        answer: handoffMessage,
        citations: ['Clinical Safety Protocol'],
        isClinicalHandoff: true,
        isGrounded: false,
        confidence: 1.0,
      };
    }

    // 2. Fetch custom documents from clinicDocuments if available, combine with canonical
    let candidateDocs: Array<{ id: string; title: string; content: string; keywords: string[] }> = [
      ...this.CANONICAL_DOCS,
    ];

    if (!(process.env.NODE_ENV === 'test' && !process.env.FIRESTORE_EMULATOR_HOST)) {
      try {
        const customSnap = await db
          .collection(COLLECTIONS.CLINIC_DOCUMENTS)
          .where('clinicId', '==', clinicId)
          .get();

        if (!customSnap.empty) {
          customSnap.forEach((doc) => {
            const d = doc.data() as ClinicFaqDocument;
            candidateDocs.push({
              id: d.id || doc.id,
              title: d.title,
              content: d.content,
              keywords: d.keywords || [],
            });
          });
        }
      } catch {
        // Fallback to canonical
      }
    }

    // 3. Grounded Retrieval Matching
    const queryTokens = this.tokenize(query);
    if (queryTokens.length === 0) {
      return {
        answer: 'How can we help you? You can ask about our clinic timings, location, services, or appointment policies.',
        citations: [],
        isClinicalHandoff: false,
        isGrounded: false,
        confidence: 0,
      };
    }

    let bestDoc: (typeof candidateDocs)[0] | null = null;
    let highestScore = 0;

    for (const doc of candidateDocs) {
      const docTokens = this.tokenize(doc.title + ' ' + doc.content + ' ' + doc.keywords.join(' '));
      let matches = 0;

      for (const qt of queryTokens) {
        if (docTokens.includes(qt)) {
          matches++;
        }
      }

      // Keyword boost
      for (const kw of doc.keywords) {
        if (query.toLowerCase().includes(kw.toLowerCase())) {
          matches += 2;
        }
      }

      const score = matches / Math.sqrt(queryTokens.length * 2);
      if (score > highestScore) {
        highestScore = score;
        bestDoc = doc;
      }
    }

    // Grounding confidence threshold
    const GROUNDING_THRESHOLD = 0.45;

    if (!bestDoc || highestScore < GROUNDING_THRESHOLD) {
      await AuditService.log({
        clinicId,
        userId: patientId,
        action: 'FAQ_HANDOFF_UNGROUNDED',
        entityType: 'conversation',
        entityId: patientId,
        details: {
          querySnippet: query.substring(0, 50),
          highestScore,
          reason: 'Query could not be grounded in verified clinic documents. Handed off to reception.',
        },
      });

      let ungroundedMessage =
        "I don't have verified clinic information on that specific topic. I've noted your question for our clinic staff, who will assist you shortly.";
      if (preferredLanguage === 'hi') {
        ungroundedMessage =
          'हमारे क्लिनिक रिकॉर्ड में इस विषय पर सटीक जानकारी उपलब्ध नहीं है। मैंने आपका प्रश्न क्लिनिक स्टाफ को भेज दिया है, वे जल्द सहायता करेंगे।';
      } else if (preferredLanguage === 'mr') {
        ungroundedMessage =
          'आमच्या क्लिनिक रेकॉर्डमध्ये या विषयावर निश्चित माहिती उपलब्ध नाही. मी आपला प्रश्न क्लिनिक कर्मचाऱ्यांना पाठवला आहे, ते लवकरच मदत करतील.';
      }

      return {
        answer: ungroundedMessage,
        citations: [],
        isClinicalHandoff: false,
        isGrounded: false,
        confidence: highestScore,
      };
    }

    // Return grounded answer with mandatory source citation
    const groundedAnswer = `${bestDoc.content}\n\n[Source: ${bestDoc.title}]`;

    return {
      answer: groundedAnswer,
      citations: [bestDoc.title],
      isClinicalHandoff: false,
      isGrounded: true,
      confidence: highestScore,
    };
  }
}
